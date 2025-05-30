import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:intl/intl.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:convert/convert.dart';

import 'AudioFileWriter.dart';

class XunFeiRTASR {
  static const String appId = "c07df4ea";
  static const String secretKey = "6c1e25af5cce05d853c30225b0f248b6";
  static const String host = 'rtasr.xfyun.cn/v1/ws';
  static const String baseUrl = 'wss://$host';
  static const String origin = 'https://$host';
  static const int chunkedSize = 1280;

  static final DateFormat sdf = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');

  FlutterSoundRecorder? _recorder;
  bool _isRecording = false;
  bool _isPaused = false;
  bool isFirst = true;
  String code = 'cn';
  int punc = 1;
  StreamController<Uint8List>? _audioStreamController;
  WebSocketChannel? _channel;
  Function(String)? onResult;
  Function(String)? onEndResult;

  Future<void> startChannel() async {
    final Uri url;
    if (punc == 1) {
      url = Uri.parse('$baseUrl${getHandShakeParams(appId, secretKey)}&lang=$code');
    } else {
      url = Uri.parse('$baseUrl${getHandShakeParams(appId, secretKey)}&lang=$code&punc=$punc');
    }

    if (kIsWeb) {
      _channel = WebSocketChannel.connect(url);
    } else {
      _channel = IOWebSocketChannel.connect(url, headers: {'Origin': origin});
    }

    final handshakeSuccess = Completer<void>();

    _channel!.stream.listen(
          (message) {
        final msgObj = jsonDecode(message);
        print("msgObj:$msgObj");
        final action = msgObj['action'];
        if (action == 'started') {
          print('${getCurrentTimeStr()} 握手成功！sid: ${msgObj['sid']}');
          handshakeSuccess.complete();
        } else if (action == 'result') {
          final result = getContent(msgObj['data']);
          final isFinal = int.parse(jsonDecode(msgObj['data'])['cn']['st']['type']) == 0;
          if (isFinal) {
            onEndResult?.call(result);
          } else {
            onResult?.call(result);
          }
        } else if (action == 'error') {
          print('Error: $message');
        }
      },
      onError: (error) {
        print('${getCurrentTimeStr()} WebSocket 错误: $error');
      },
      onDone: () {
        print('${getCurrentTimeStr()} WebSocket 连接关闭');
      },
    );

    await handshakeSuccess.future;
    print('${sdf.format(DateTime.now())} 开始发送音频数据');
  }

  Future<void> startRecording(String code, int punc, String path) async {
    this.code = code;
    this.punc = punc;
    await startChannel();

    _recorder = FlutterSoundRecorder();
    await _recorder!.openRecorder();
    _isRecording = true;
    _isPaused = false;

    _audioStreamController = StreamController<Uint8List>.broadcast();

    await _recorder!.startRecorder(
      codec: Codec.pcm16,
      sampleRate: 16000,
      numChannels: 1,
      toStream: _audioStreamController!.sink,
      enableVoiceProcessing: true,
    );

    _audioStreamController!.stream.listen((audioData) async {
      if (_isPaused) return;
      try {
        if (_channel == null) {
          print('${getCurrentTimeStr()} WebSocket 已关闭，跳过数据发送');
          return;
        }

        _sendAudioData(audioData);
      } catch (e) {
        print('${getCurrentTimeStr()} 录音数据处理错误: $e');
      }
    });
  }

  Future<void> writeAudioData(String code, int punc, Uint8List audioData) async {
    if (isFirst) {
      isFirst = false;
      this.code = code;
      this.punc = punc;
      _isRecording = true;
      _isPaused = false;
    }

    if (_isPaused) return;
    try {
      if (_channel == null) {
        print('${getCurrentTimeStr()} WebSocket 已关闭，跳过数据发送');
        return;
      }
      _sendAudioData(audioData);
    } catch (e) {
      print('${getCurrentTimeStr()} 录音数据处理错误: $e');
    }
  }

  void _sendAudioData(Uint8List audioData) {
    if (_channel == null) return;
    if (audioData.length > chunkedSize) {
      final chunks = audioData.length ~/ chunkedSize;
      for (int i = 0; i < chunks; i++) {
        final chunk = audioData.sublist(i * chunkedSize, (i + 1) * chunkedSize);
        _channel!.sink.add(chunk);
      }
      final remaining = audioData.length % chunkedSize;
      if (remaining > 0) {
        final chunk = audioData.sublist(audioData.length - remaining);
        _channel!.sink.add(chunk);
      }
    } else {
      _channel!.sink.add(audioData);
    }
  }

  Future<void> stopWriteData() async {
    isFirst = true;
    _isRecording = false;
    _isPaused = false;
    onResult = (String msg) {};
    onEndResult = (String msg) {};
    if (_audioStreamController != null) {
      await _audioStreamController!.close();
    }

    if (_channel != null) {
      _channel!.sink.add(utf8.encode('{"end": true}'));
      await _channel!.sink.close();
    }
  }

  Future<void> stopRecording() async {
    if (_recorder != null) {
      await _recorder!.stopRecorder();
      await _recorder!.closeRecorder();
    }
    _isRecording = false;
    _isPaused = false;
    if (_audioStreamController != null) {
      await _audioStreamController!.close();
    }

    if (_channel != null) {
      _channel!.sink.add(utf8.encode('{"end": true}'));
      await _channel!.sink.close();
    }
  }

  Future<void> pauseRecording() async {
    if (_isRecording && !_isPaused) {
      _isPaused = true;
      _channel?.sink.add(utf8.encode('{"end": true}'));
      await _channel?.sink.close();
      await _recorder!.pauseRecorder();
      print('${getCurrentTimeStr()} 录音已暂停');
    }
  }

  Future<void> resumeRecording() async {
    if (_isRecording && _isPaused) {
      _isPaused = false;
      await startChannel();
      await _recorder!.resumeRecorder();
      print('${getCurrentTimeStr()} 录音已恢复');
    }
  }

  static String getHandShakeParams(String appId, String secretKey) {
    String ts = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    String md5Hash = md5Encrypt(appId + ts);
    String signa = hmacSHA1Encrypt(md5Hash, secretKey);
    return "?appid=$appId&ts=$ts&signa=${Uri.encodeComponent(signa)}";
  }

  static String getCurrentTimeStr() {
    return sdf.format(DateTime.now());
  }

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
