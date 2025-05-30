import 'dart:convert';
// import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_sound/flutter_sound.dart';

class XunFeiTTS {
  static const String hostUrl = 'https://tts-api.xfyun.cn/v2/tts';
  static const String appId = 'c07df4ea';
  static const String apiSecret = 'YTE0M2FkMTQzNTJmZDMxOWEzY2M3YjFh';
  static const String apiKey = 'ee4977e6d32127deea72e020bc108e65';

  MethodChannel methodChannel = MethodChannel('pcm_audio');

  String vcn = "x4_lingxiaoying_assist"; // 发音人
  final String tte = "UTF8"; // 编码格式
  late String filePath;
  late WebSocketChannel _channel;

  List<int> completeAudioData = [];
  bool wsCloseFlag = false;

  FlutterSoundPlayer? _player;
  late bool isTTS = false;

  Future<void> startTTS(
      String ttsText,
      String voice,
      Function(String filePath) callback,
      Function() playEnd,
      bool isPlay) async {
    vcn = voice;
    completeAudioData.clear();
    filePath = "";
    int count = 0;
    if (isPlay) {
      isTTS = true;
      //_player = FlutterSoundPlayer();
      //await _player!.openPlayer();
      methodChannel.invokeMethod('initAudioTrack', {
        'sampleRate': 16000,
        'channel': 1,
      });
      methodChannel.setMethodCallHandler((call) async {
        if (call.method == "playbackComplete") {
          print("PCM播放完成");
          playEnd();
          await methodChannel.invokeMethod('stopAudioTrack');
        }
      });
    }
    // 初始化播放器

    String wsUrl = await _getAuthUrl();
    _channel = WebSocketChannel.connect(
        Uri.parse(wsUrl.replaceFirst('https://', 'wss://')));

    _channel.stream.listen((message) {
      _onMessage(message, callback, playEnd, isPlay);
    }, onError: (error) {
      print("WebSocket错误: $error");
    }, onDone: () {
      print("WebSocket连接关闭");
    });

    _sendRequest(ttsText);
  }

  Future<void> stop()
  async {
    isTTS = false;
    await methodChannel.invokeMethod('stopAudioTrack');
  }

  void _sendRequest(String ttsText) {
    String requestJson = '''
      {
        "common": {
          "app_id": "$appId"
        },
        "business": {
          "aue": "raw",
          "tte": "$tte",
          "ent": "intp65",
          "vcn": "$vcn",
          "pitch": 50,
          "speed": 50
        },
        "data": {
          "status": 2,
          "text": "${base64Encode(utf8.encode(ttsText))}"
        }
      }
    ''';
    print("TTS请求参数:$requestJson");
    _channel.sink.add(requestJson);
  }

  Future<void> _onMessage(dynamic message, Function(String filePath) callback,
      Function() playEnd, isPlay) async {
    var jsonResponse = jsonDecode(message);
    if (filePath.isEmpty) {
      final directory = await getTemporaryDirectory();
      filePath = '${directory.path}/${jsonResponse['sid']}.pcm';
    }
    if (jsonResponse['code'] != 0) {
      print('发生错误，错误码为：${jsonResponse['code']}');
    } else {
      var audioData = jsonResponse['data']['audio'];
      if (audioData != null) {
        var decodedAudio = base64Decode(audioData);
        completeAudioData.addAll(decodedAudio);
        if(isTTS)
          await methodChannel.invokeMethod('playPCMData', decodedAudio);
      }
      if (jsonResponse['data']['status'] == 2) {
        wsCloseFlag = true;
        _channel.sink.close();
        if (isPlay) {
          // await _player!.startPlayer(
          //   codec: Codec.pcm16,
          //   numChannels: 1,
          //   sampleRate: 16000,
          //   // 讯飞TTS默认16000Hz
          //   fromDataBuffer: Uint8List.fromList(completeAudioData),
          //   whenFinished: () {
          //     playEnd();
          //     _player?.closePlayer();
          //   },
          // );
        }
        _saveAudio(Uint8List.fromList(completeAudioData), callback);
      }
    }
  }

  void _saveAudio(
      Uint8List audioData, Function(String filePath) callback) async {
    print("开始保存音频数据:$filePath");
    // final file = File(filePath);
    // try {
    //   await file.writeAsBytes(audioData);
    //   callback(filePath); // 回调音频文件路径
    // } catch (e) {
    //   print("保存音频时出错: $e");
    // }
  }

  Future<String> _getAuthUrl() async {
    final uri = Uri.parse(hostUrl);
    final String date = _formatHttpDate(DateTime.now().toUtc());
    final String signatureOrigin =
        'host: ${uri.host}\ndate: $date\nGET ${uri.path} HTTP/1.1';
    final hmac = Hmac(sha256, utf8.encode(apiSecret));
    final String signature =
    base64.encode(hmac.convert(utf8.encode(signatureOrigin)).bytes);

    final authorization = 'api_key="$apiKey", algorithm="hmac-sha256", '
        'headers="host date request-line", signature="$signature"';
    final queryParameters = {
      'authorization': base64.encode(utf8.encode(authorization)),
      'date': date,
      'host': uri.host,
    };

    final authUri = uri.replace(queryParameters: queryParameters);
    return authUri.toString();
  }

// 替代 HttpDate.format(DateTime.now().toUtc())
  String _formatHttpDate(DateTime date) {
    // RFC 1123 格式
    final weekday = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1];
    final month = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][date.month - 1];
    return '$weekday, ${date.day.toString().padLeft(2, '0')} $month ${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')} GMT';
  }

  void dispose() {
    _player?.closePlayer();
    _player = null;
  }
}
