import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class XunFeiMachineTranslation {
  static String requestUrl = "https://itrans.xf-yun.com/v1/its";
  static const String appId = 'c07df4ea';
  static const String apiSecret = 'YTE0M2FkMTQzNTJmZDMxOWEzY2M3YjFh';
  static const String apiKey = 'ee4977e6d32127deea72e020bc108e65';

  // static const String appId = "366309a9";
  // static const String apiSecret = "YTZiMWYwYzBjOTRlNzUyNmEwNzg5YTU5";
  // static const String apiKey = "44791e14c7a252faf0846d12f945b112";
  static String resId = "its_cn_en_word";

  static Future<void> sendMessage(String text, String from, String to,
      Function(String) onSuccess, Function(String) onError) async {
    try {
      String response = await _doRequest(text, from, to);

      // 解析 JSON 数据
      var jsonResponse = jsonDecode(response);
      String textBase64Decode =
      utf8.decode(base64Decode(jsonResponse['payload']['result']['text']));
      // 解析翻译结果
      var translationResponse = jsonDecode(textBase64Decode);
      String translatedText =
      translationResponse['trans_result']['dst']; // 提取目标语言翻译

      // 直接返回翻译结果
      onSuccess(translatedText);
    } catch (e) {
      onError("Error: $e");
    }
  }

  static Future<String> _doRequest(String text, String from, String to) async {
    Uri url = Uri.parse(_buildRequestUrl());
    http.Client client = http.Client();
    http.Request request = http.Request("POST", url);
    request.headers.addAll({
      "Content-Type": "application/json",
    });
    request.body = _buildParam(text, from, to);

    try {
      http.Response response = await client
          .send(request)
          .then((responseStream) => http.Response.fromStream(responseStream));
      return response.body;
    } catch (e) {
      throw Exception("Request failed: $e");
    }
  }

  static String _buildRequestUrl() {
    DateTime now = DateTime.now().toUtc();
    String formattedDate = _formatDate(now);

    String authorization = _generateAuthorization(formattedDate);

    return "$requestUrl?authorization=${Uri.encodeComponent(authorization)}&host=${Uri.encodeComponent("itrans.xf-yun.com")}&date=${Uri.encodeComponent(formattedDate)}";
  }

  static String _generateAuthorization(String date) {
    String canonicalString = "host: itrans.xf-yun.com\n"
        "date: $date\n"
        "POST /v1/its HTTP/1.1";

    List<int> hmacSha256 = _hmacSha256(apiSecret, canonicalString);
    String signature = base64Encode(hmacSha256);

    String authorization =
        "api_key=\"$apiKey\", algorithm=\"hmac-sha256\", headers=\"host date request-line\", signature=\"$signature\"";

    return base64Encode(utf8.encode(authorization));
  }

  static List<int> _hmacSha256(String secret, String data) {
    var key = utf8.encode(secret);
    var bytes = utf8.encode(data);

    var hmac = Hmac(sha256, key); // HMAC-SHA256
    return hmac.convert(bytes).bytes;
  }

  static String _formatDate(DateTime date) {
    final formatter = DateFormat("EEE, dd MMM yyyy HH:mm:ss 'GMT'", 'en_US');
    return formatter.format(date);
  }

  static String _buildParam(String text, String from, String to) {
    var payload = jsonEncode({
      "header": {
        "app_id": appId,
        "status": 3,
        "res_id": resId,
      },
      "parameter": {
        "its": {"from": from, "to": to, "result": {}}
      },
      "payload": {
        "input_data": {
          "encoding": "utf8",
          "status": 3,
          "text": base64Encode(utf8.encode(text)),
        }
      }
    });

    return payload;
  }
}
