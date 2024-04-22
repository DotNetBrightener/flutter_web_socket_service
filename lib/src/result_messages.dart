import 'messages.dart';

class ResponseResult {
  static const String defaultConnectionErrorMessage =
      "Error while trying to connect to server";
  String? errorMessage;
  Object? error;
  BasePayload? payload;

  ResponseResult({
    this.errorMessage,
    this.error,
    this.payload,
  });

  Map<String, dynamic> toJson() {
    return payload?.toJson() ?? {};
  }
}

class ConnectResult {
  static const String defaultConnectionErrorMessage =
      "Unable to establish the connection";
  String? errorMessage;
  Object? error;
  String? connectionId;

  ConnectResult({
    this.errorMessage,
    this.error,
    this.connectionId,
  });

  Map<String, dynamic> toJson() {
    return {
      'connectionId': connectionId,
      'errorMessage': errorMessage,
      'error': error,
    };
  }
}
