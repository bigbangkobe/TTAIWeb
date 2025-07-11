import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:convert/convert.dart';

class XunFeiRTASR {
  static const String appId = "b32dc8bb";
  static const String secretKey = "f1ff6437fbf880406e05c63fb4a054d4";
  static const String baseUrl = 'wss://naturich.top:3000/rtasr';
  static const int chunkedSize = 1280;

  static final DateFormat sdf = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');

  bool _isConnected = false;
  bool _isPaused = false;
  bool isFirst = true;
  String code = 'cn';
  int punc = 1;
  WebSocketChannel? _channel;
  Function(String)? onResult;
  Function(String)? onEndResult;

  String chanelName = "";

  Future<void> startChannel(String name) async {
    chanelName = name;
    final Uri url;
    if (punc == 1) {
      url = Uri.parse(
          '$baseUrl${getHandShakeParams(appId, secretKey)}&lang=$code');
    } else {
      url = Uri.parse(
          '$baseUrl${getHandShakeParams(appId, secretKey)}&lang=$code&punc=$punc');
    }

    try {
      // 跨平台兼容的连接方式
      if (kIsWeb) {
        // Web 平台不需要 headers
        _channel = WebSocketChannel.connect(url);
      } else {
        // 移动平台使用 IOWebSocketChannel 并添加 headers
        _channel = WebSocketChannel.connect(
          url,
          protocols: [],
        );
        // if (_channel is IOWebSocketChannel) {
        //   (_channel as IOWebSocketChannel).innerWebSocket?.setRequestHeader('Origin', origin);
        // }
      }

      final handshakeSuccess = Completer<void>();

      _channel!.stream.listen(
            (message) {
          String raw;
          if (message is String) {
            raw = message;
          } else if (message is ByteBuffer) {
            raw = utf8.decode(message.asUint8List());
          } else if (message is List<int>) {
            raw = utf8.decode(message);
          } else {
            print('emmmmmm $chanelName 未知消息类型：$message');
            return;
          }

          print('emmmmmm $chanelName ${getCurrentTimeStr()} raw: $raw');
          final msgObj = jsonDecode(raw);
          print('emmmmmm $chanelName ${getCurrentTimeStr()} msg: $msgObj');
          final action = msgObj['action'];
          if (action == 'started') {
            print('emmmmmm $chanelName ${getCurrentTimeStr()} 握手成功！sid: ${msgObj['sid']}');
            _isConnected = true;
            handshakeSuccess.complete();
          } else if (action == 'result') {
            final result = getContent(msgObj['data']);
            final isFinal =
                int.parse(jsonDecode(msgObj['data'])['cn']['st']['type']) == 0;
            if (isFinal) {
              onEndResult?.call(result);
            } else {
              onResult?.call(result);
            }
          } else if (action == 'error') {
            print('emmmmmm $chanelName Error: $message');
            _isConnected = false;
          }
        },
        onError: (error) {
          print('emmmmmm $chanelName ${getCurrentTimeStr()} WebSocket 错误: $error');
          _isConnected = false;
        },
        onDone: () {
          print('emmmmmm $chanelName ${getCurrentTimeStr()} WebSocket 连接关闭');
          _isConnected = false;
        },
      );

      await handshakeSuccess.future;
      print('emmmmmm $chanelName ${sdf.format(DateTime.now())} 开始发送音频数据');

    } catch (e) {
      print('emmmmmm $chanelName ${getCurrentTimeStr()} 连接错误: $e');
      rethrow;
    }
  }

  Future<void> writeAudioData(String code, int punc, Uint8List audioData) async {
    if (isFirst) {
      isFirst = false;
      this.code = code;
      this.punc = punc;
      _isPaused = false;
    }
    // print('emmmmmm ${getCurrentTimeStr()} writeAudioData发送音频数据$_isPaused,$_isConnected');
    if (_isPaused || !_isConnected) return;
    // print('emmmmmm ${getCurrentTimeStr()} writeAudioData发送音频数据$audioData');
    try {
      if (audioData.isEmpty) return;
      // print('emmmmmm ${getCurrentTimeStr()} writeAudioData发送音频数据,数据不为null');
      if (audioData.length > chunkedSize) {
        final chunks = audioData.length ~/ chunkedSize;
        for (int i = 0; i < chunks; i++) {
          final chunk = audioData.sublist(
            i * chunkedSize,
            (i + 1) * chunkedSize,
          );
          _sendBinary(chunk);
        }
        final remaining = audioData.sublist(chunks * chunkedSize);
        if (remaining.isNotEmpty) {
          _sendBinary(remaining);
        }
      } else {
        _sendBinary(audioData);
      }
    } catch (e) {
      print('emmmmmm $chanelName ${getCurrentTimeStr()} 音频处理错误: $e');
    }
  }

  void _sendBinary(Uint8List data) {
    // print('emmmmmm ${getCurrentTimeStr()} _sendBinary: $data');
    if (_channel?.closeCode != null) return;
    try {
      // print('emmmmmm $chanelName ${getCurrentTimeStr()} _channel?.sink.add: $data');
      _channel?.sink.add(data);
    } catch (e) {
      print('emmmmmm $chanelName ${getCurrentTimeStr()} 发送错误: $e');
      _isConnected = false;
    }
  }

  Future<void> stopChannel() async {
    isFirst = true;
    _isPaused = false;

    try {
      if (_channel?.closeCode == null) {
        _channel?.sink.add('{"end": true}');
        await _channel?.sink.close();
      }
    } catch (e) {
      print('emmmmmm $chanelName ${getCurrentTimeStr()} 关闭错误: $e');
    } finally {
      _isConnected = false;
      _channel = null;
    }
  }

  void pause() => _isPaused = true;
  void resume() => _isPaused = false;

  static String getHandShakeParams(String appId, String secretKey) {
    String ts = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    String md5Hash = md5Encrypt(appId + ts);
    String signa = hmacSHA1Encrypt(md5Hash, secretKey);
    return "?appid=$appId&ts=$ts&signa=${Uri.encodeComponent(signa)}";
  }

  static String getCurrentTimeStr() => sdf.format(DateTime.now());

  static String getContent(String message) {
    final resultBuilder = StringBuffer();
    try {
      final messageObj = jsonDecode(message);
      final cn = messageObj['cn'];
      final st = cn['st'];
      final rtArr = st['rt'];
      for (var rt in rtArr) {
        final wsArr = rt['ws'];
        for (var ws in wsArr) {
          final cwArr = ws['cw'];
          for (var cw in cwArr) {
            resultBuilder.write(cw['w']);
          }
        }
      }
    } catch (e) {
      return message;
    }
    return resultBuilder.toString();
  }

  static String hmacSHA1Encrypt(String encryptText, String encryptKey) {
    final key = Hmac(sha1, utf8.encode(encryptKey));
    final digest = key.convert(utf8.encode(encryptText));
    return base64.encode(digest.bytes);
  }

  static String md5Encrypt(String input) {
    return hex.encode(md5.convert(utf8.encode(input)).bytes);
  }
}