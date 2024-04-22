import 'package:archive/archive.dart';
import 'dart:convert';

import 'messages.dart';

extension Compress on RequestMessage {
  List<int> compress() {
    String jsonRequest = jsonEncode(this);
    List<int> jsonRequestBytes = utf8.encode(jsonRequest);
    List<int> jsonRequestGzip =
        GZipEncoder().encode(jsonRequestBytes) as List<int>;
    return jsonRequestGzip;
  }
}

class MessageCompressionService {
  static Map<String, dynamic> decompress(dynamic message) {
    List<int> responseBytes = GZipDecoder().decodeBytes(message);
    String decodedMessage = utf8.decode(responseBytes);
    return jsonDecode(decodedMessage) as Map<String, dynamic>;
  }
}
