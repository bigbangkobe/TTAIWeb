import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:convert/convert.dart';

class XunFeiRTASR {
  static const String appId = "c07df4ea";
  static const String secretKey = "6c1e25af5cce05d853c30225b0f248b6";
  static const String host = 'rtasr.xfyun.cn/v1/ws';
  static const String baseUrl = 'wss://$host';
  static const String origin = 'https://$host';
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

  Future<void> startChannel() async {
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
          final msgObj = jsonDecode(message);
          final action = msgObj['action'];
          if (action == 'started') {
            print('${getCurrentTimeStr()} 握手成功！sid: ${msgObj['sid']}');
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
            print('Error: $message');
            _isConnected = false;
          }
        },
        onError: (error) {
          print('${getCurrentTimeStr()} WebSocket 错误: $error');
          _isConnected = false;
        },
        onDone: () {
          print('${getCurrentTimeStr()} WebSocket 连接关闭');
          _isConnected = false;
        },
      );

      await handshakeSuccess.future;
      print('${sdf.format(DateTime.now())} 开始发送音频数据');
    } catch (e) {
      print('${getCurrentTimeStr()} 连接错误: $e');
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

    if (_isPaused || !_isConnected) return;

    try {
      if (audioData.isEmpty) return;

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
      print('${getCurrentTimeStr()} 音频处理错误: $e');
    }
  }

  void _sendBinary(Uint8List data) {
    if (_channel?.closeCode != null) return;
    try {
      _channel?.sink.add(data);
    } catch (e) {
      print('${getCurrentTimeStr()} 发送错误: $e');
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
      print('${getCurrentTimeStr()} 关闭错误: $e');
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