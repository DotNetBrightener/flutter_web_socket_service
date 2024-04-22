import 'package:uuid/uuid.dart';

class BasePayload {
  Map<String, dynamic>? data;

  BasePayload([this.data]);

  Map<String, dynamic> toJson() {
    return data ?? {};
  }

  BasePayload.fromJson(Map<String, dynamic> json) {
    data = Map.from(json);
  }
}

class RequestMessage {
  String connectionId;
  String id;
  String action;
  Map<String, dynamic> payload;

  RequestMessage({
    required this.connectionId,
    required this.action,
    required BasePayload basePayload,
  })  : id = const Uuid().v4(),
        payload = basePayload.toJson();

  Map<String, dynamic> toJson() {
    final jsonPayload = <String, dynamic>{
      "connectionId": connectionId,
      "id": id,
      "action": action,
    };

    for (var key in payload.keys) {
      jsonPayload[key] = payload[key];
    }

    return jsonPayload;
  }
}

class ResponseMessage {
  String id;
  String connectionId;
  String action;
  String? errorMessage;
  Map<String, dynamic>? payload;
  Map<String, dynamic> rawPayloadData;

  ResponseMessage.fromJson(Map<String, dynamic> json)
      : id = json["id"],
        connectionId = json["connectionId"],
        action = json["action"],
        errorMessage = json["errorMessage"],
        payload = json["payload"] != null ? Map.from(json["payload"]) : null,
        rawPayloadData = json;

  Map<String, dynamic> toJson() {
    final jsonPayload = <String, dynamic>{
      "connectionId": connectionId,
      "id": id,
      "action": action,
    };

    for (var key in rawPayloadData.keys) {
      jsonPayload[key] = rawPayloadData[key];
    }

    return jsonPayload;
  }
}
