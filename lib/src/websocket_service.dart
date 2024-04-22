import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../websocket_channel/channel.dart';
import 'message_compression_service.dart';
import 'messages.dart';
import 'result_messages.dart';

class WebSocketService {
  late String? baseUrl;
  bool requireAuth = false;
  late String? websocketEndpoint;
  late String? initialAuthToken;
  late String initAuthEndpoint;
  late WebSocketChannel _channel;
  late Map<String, String> customHeaders = {};

  String? _connectionId;
  final Map<String, Completer<ResponseResult>> _requests = {};
  final Map<String, List<Future Function(dynamic)>> _eventListeners = {};
  late Completer<ConnectResult> _waitingConnectionCompleter;
  Completer? _onDoneCompleter;

  bool _waitingConnection = false;

  bool get connected => _connectionId != null;

  WebSocketService({
    required this.baseUrl,
    this.initAuthEndpoint = 'wss_auth',
    this.websocketEndpoint = 'wss',
    this.initialAuthToken,
    this.requireAuth = false,
    this.customHeaders = const {},
  });

  void addEventListener(String s, Future Function(dynamic response) callback) {
    if (_eventListeners[s] == null) {
      _eventListeners[s] = [];
    }

    _eventListeners[s]!.add(callback);
  }

  Future<ConnectResult> connect() async {
    if (_waitingConnection || _connectionId != null) {
      return _waitingConnectionCompleter.future;
    }

    _waitingConnection = true;
    _waitingConnectionCompleter = Completer<ConnectResult>();
    _onDoneCompleter = Completer();

    if (requireAuth) {
      if (initialAuthToken == null) {
        throw Exception('initialAuthToken is required');
      }
      final authExchangeEndpoint =
          Uri.parse('https://$baseUrl/$initAuthEndpoint');

      http.Client client = http.Client();
      try {
        final Map<String, String> headers = {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $initialAuthToken',
        };

        headers.addAll(customHeaders);

        final value = await client.post(authExchangeEndpoint, headers: headers);

        final response = Map.from(jsonDecode(value.body));
        _connectionId = response['cnnToken'];
      } catch (ex) {
        throw Exception(
            'Unable to authenticate prior to connecting to websocket');
      }
    }

    final queryParameters = {};

    if (_connectionId != null) {
      queryParameters['wss_token'] = _connectionId!;
    }

    final url = Uri.parse(
        'wss://$baseUrl/$websocketEndpoint?${queryParameters.entries.map((e) => '${e.key}=${e.value}').join('&')}');

    _channel = WebSocketChannel.connect(url, protocols: ['wss']);
    _channel.stream.listen(
      _onData,
      onError: (error) async => _onError(error),
      onDone: _onDone,
    );

    return _waitingConnectionCompleter.future;
  }

  Future<ResponseResult> request(String action,
      {required BasePayload payload}) async {
    await _ensureConnected();

    final request = RequestMessage(
      connectionId: _connectionId!,
      action: action,
      basePayload: payload,
    );

    print('request: ${jsonEncode(request)}');

    final completer = Completer<ResponseResult>();

    _requests[request.id] = completer;
    _channel.sink.add(request.compress());

    return completer.future;
  }

  Future<dynamic> close() async {
    if (connected) {
      await _channel.sink.close();
      initialAuthToken = null;
      requireAuth = false;
      if (_onDoneCompleter != null) {
        return _onDoneCompleter!.future;
      }
    }
    return Future.value();
  }

  Future _ensureConnected() async {
    if (_waitingConnection) {
      await connect();
    }
    if (!connected) {
      await connect();
    }
  }

  void _onData(dynamic message) {
    if (message == 'pong') {
      debugPrint('pong received');
      return;
    }

    final response = MessageCompressionService.decompress(message);

    if (_waitingConnection) {
      assert(response['action'] == "ConnectedNotification");
      _connectionId = response['connectionId'];
      _waitingConnectionCompleter.complete(ConnectResult(
        connectionId: _connectionId,
      ));
      _waitingConnection = false;

      Timer.periodic(const Duration(seconds: 75), (timer) {
        if (_connectionId == null) {
          timer.cancel();
          return;
        }

        debugPrint('sending ping');
        _channel.sink.add('ping');
      });

      return;
    }

    BasePayload? responsePayload = BasePayload.fromJson(response);

    if (_requests.containsKey(response['id'])) {
      _requests[response['id']]!.complete(ResponseResult(
        errorMessage: response['errorMessage'],
        payload: responsePayload,
      ));
      _requests.remove(response['id']);
    }

    _eventListeners[response['action']]?.forEach((element) {
      element(response);
    });
  }

  Future<void> _onError(Object error) async {
    if (_waitingConnection) {
      _waitingConnectionFailed(error: error);
      return;
    }

    await close();
  }

  void _onDone() {
    if (_waitingConnection) {
      _waitingConnectionFailed(
          errorMessage: ConnectResult.defaultConnectionErrorMessage);
      return;
    }

    _terminateActiveRequests(
        errorMessage: ResponseResult.defaultConnectionErrorMessage);

    _connectionId = null;

    if (_onDoneCompleter != null && !_onDoneCompleter!.isCompleted) {
      _onDoneCompleter!.complete();
    }
  }

  void _terminateActiveRequests({
    String? errorMessage,
    Object? error,
  }) {
    assert(errorMessage != null || error != null);

    if (_requests.isNotEmpty) {
      for (var item in _requests.entries) {
        if (!item.value.isCompleted) {
          ResponseResult responseResult = ResponseResult(
            errorMessage: errorMessage,
            error: error,
          );

          item.value.complete(responseResult);
        }
      }
      _requests.clear();
    }
  }

  void _waitingConnectionFailed({
    String? errorMessage,
    Object? error,
  }) {
    _waitingConnectionCompleter.complete(
      ConnectResult(
        errorMessage: errorMessage,
        error: error,
      ),
    );
    _waitingConnection = false;
  }
}
