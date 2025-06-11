import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:zego_express_engine/zego_express_engine.dart';

class ZegoConfig {
  static final ZegoConfig instance = ZegoConfig._internal();
  ZegoConfig._internal();

  int appID = 563682924;

  // It is for native only, do not use it for web!
  String appSign = "271026b298228cc7f6e241890f6edc5ae1a4b417077ffba8ccb7a9e4af03da37";

  // It is required for web and is recommended for native but not required.
  String token = "04AAAAAGgAvskADNg1vFqEs7pCh4k3IACs0Z7UFwV8HC4aKNGxF92cK4dWS/uD21iZlYmCilBgWSfWSrLw8bZ3QY3T0i8xim/k1XebhffdZQLI6j+sOAAzp+UohLP5PFas1x368sRUb3JPE2gwncgyqfwn+n9GlLVUzvHuzmdsbnhsJJoJxPe7mdjEdmTz4HTf/J2XqSdCtzYcSUyVN23VHhGNh1smIeUOWiSeYPBNr26/F8dt3eDjolJdKy5LM9nDhJzYdQE=";
  String secret = "d657151df8d6db538167f0e06c5ff479";

  ZegoScenario scenario = ZegoScenario.General;
  bool enablePlatformView = true;

  String userID = "123";
  String userName = "123";
  String room = "room";
  ///app端左边语言
  int leftLanguageIndex = 0;
  ///app端右边语言
  int rightLanguageIndex = 1;

  bool isPreviewMirror = true;
  bool isPublishMirror = false;

  bool enableHardwareEncoder = false;
}

Future<String?> generateAgoraToken(String tokenType, String channel, String role, int uid, int expire) async {
  const String apiUrl = "http://139.9.213.228:3000/token/getNew"; // 云端生成 token 的地址

  // 请求 body
  final Map<String, dynamic> body = {
    "tokenType": tokenType,
    "channel": channel,
    "role": role,
    "uid": uid.toString(),
    "expire": expire,
  };

  // 发送 POST 请求到云端 API
  try {
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        "Content-Type": "application/json",
      },
      body: json.encode(body), // 将请求体转为 JSON
    );

    // 检查服务器返回的状态码
    if (response.statusCode == 200) {
      // 如果请求成功，返回生成的 token
      final Map<String, dynamic> responseData = json.decode(response.body);
      return responseData['token'];  // 假设服务器返回的 JSON 包含 'token' 字段
    } else {
      print("Failed to generate token: ${response.statusCode}");
      return null;
    }
  } catch (e) {
    print("Error: $e");
    return null;
  }
}

Future<String?> generateZegoToken(int appId, String userId, String secret, int effectiveTimeInSeconds, String payload) async {
  const String apiUrl = "https://naturich.top:3000/api/token/zegoGenerateToken"; // 云端生成 token 的地址

  // 请求 body
  final Map<String, dynamic> body = {
    "appId": appId,
    "userId": userId,
    "secret": secret,
    "effectiveTimeInSeconds": effectiveTimeInSeconds,
    "payload": payload,
  };

  // 发送 POST 请求到云端 API
  try {
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        "Content-Type": "application/json",
      },
      body: json.encode(body), // 将请求体转为 JSON
    );

    // 检查服务器返回的状态码
    if (response.statusCode == 200) {
      // 如果请求成功，返回生成的 token
      final Map<String, dynamic> responseData = json.decode(response.body);
      return responseData['token'];  // 假设服务器返回的 JSON 包含 'token' 字段
    } else {
      print("Failed to generate token: ${response.statusCode}");
      return "";
    }
  } catch (e) {
    print("Error: $e");
    return "";
  }
}

