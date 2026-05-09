import 'dart:convert';

class QRService {
  String generateQR(Map<String, dynamic> data) {
    return jsonEncode(data);
  }

  Map<String, dynamic> decodeQR(String data) {
    return jsonDecode(data);
  }
}
