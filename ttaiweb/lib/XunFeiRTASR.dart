import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html;

import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:convert/convert.dart';

class XunFeiRTASR {
  static const String appId = "c07df4ea";
  static const String secretKey = "6c1e25af5cce05d853c30225b0f248b6";
  static const String host = 'rtasr.xfyun.cn/v1/ws';
  static const String baseUrl = 'wss://$host';
  static final DateFormat sdf = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');

  html.WebSocket? _webSocket;
  bool isFirst = true;
  String code = 'cn';
  int punc = 1;

  final BytesBuilder _recordedData = BytesBuilder();

  Function(String)? onResult;
  Function(String)? onEndResult;

  Future<void> startChannel() async {
    final Uri url = Uri.parse(
      punc == 1
          ? '$baseUrl${getHandShakeParams(appId, secretKey)}&lang=$code'
          : '$baseUrl${getHandShakeParams(appId, secretKey)}&lang=$code&punc=$punc',
    );

    _webSocket = html.WebSocket(url.toString());
    final completer = Completer<void>();

    _webSocket!.onOpen.listen((event) {
      print('${getCurrentTimeStr()} WebSocket 打开');
    });

    _webSocket!.onMessage.listen((event) {
      final message = event.data;
      if (message is String) {
        final msgObj = jsonDecode(message);
        final action = msgObj['action'];
        if (action == 'started') {
          print('${getCurrentTimeStr()} 握手成功！sid: ${msgObj['sid']}');
          completer.complete();
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
        }
      }
    });

    _webSocket!.onError.listen((event) {
      print('${getCurrentTimeStr()} WebSocket 错误: $event');
    });

    _webSocket!.onClose.listen((event) {
      print('${getCurrentTimeStr()} WebSocket 连接关闭');
    });

    await completer.future;
    print('${getCurrentTimeStr()} 开始发送音频数据');
  }

  Future<void> startRecording(String code, int punc, String path) async {
    print('⚠️ Web端不支持直接 startRecording，请用外部 JS 或插件采集音频并传入 writeAudioData()');
  }

  Future<void> writeAudioData(String code, int punc, Uint8List audioData) async {
    if (isFirst) {
      isFirst = false;
      this.code = code;
      this.punc = punc;
      _recordedData.clear();
    }

    _recordedData.add(audioData);

    if (_webSocket == null || _webSocket!.readyState != html.WebSocket.OPEN) {
      print('${getCurrentTimeStr()} WebSocket 已关闭，跳过数据发送');
      return;
    }

    _webSocket!.sendTypedData(audioData);
  }

  Future<void> stopWriteData() async {
    isFirst = true;
    if (_webSocket != null && _webSocket!.readyState == html.WebSocket.OPEN) {
      _webSocket!.send(jsonEncode({'end': true}));
      _webSocket!.close();
    }

    if (_recordedData.length > 0) {
      // final filename = 'recorded_audio_${DateTime.now().millisecondsSinceEpoch}.wav';
      // saveAudioToFile(_recordedData.toBytes(), filename);
      _recordedData.clear();
    }
  }

  Future<void> stopRecording() async {
    await stopWriteData();
  }

  Future<void> pauseRecording() async {
    print('⚠️ Web端不支持 pauseRecording');
  }

  Future<void> resumeRecording() async {
    print('⚠️ Web端不支持 resumeRecording');
  }

  /// 把 PCM 数据封装成 WAV 并保存为文件
  void saveAudioToFile(Uint8List pcmData, String filename) {
    final wavData = _convertPCMToWAV(pcmData);
    final blob = html.Blob([wavData]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", filename)
      ..click();
    html.Url.revokeObjectUrl(url);
    print('${getCurrentTimeStr()} 保存音频文件: $filename');
  }

  Uint8List _convertPCMToWAV(Uint8List pcmData, {
    int sampleRate = 16000,
    int numChannels = 1,
    int bitsPerSample = 16,
  }) {
    int byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    int blockAlign = numChannels * bitsPerSample ~/ 8;
    int dataSize = pcmData.length;

    final header = BytesBuilder();
    header.add(ascii.encode('RIFF')); // Chunk ID
    header.add(_uint32ToBytes(36 + dataSize)); // Chunk Size
    header.add(ascii.encode('WAVE')); // Format
    header.add(ascii.encode('fmt ')); // Subchunk1 ID
    header.add(_uint32ToBytes(16)); // Subchunk1 Size (16 for PCM)
    header.add(_uint16ToBytes(1)); // Audio Format (1 = PCM)
    header.add(_uint16ToBytes(numChannels)); // Num Channels
    header.add(_uint32ToBytes(sampleRate)); // Sample Rate
    header.add(_uint32ToBytes(byteRate)); // Byte Rate
    header.add(_uint16ToBytes(blockAlign)); // Block Align
    header.add(_uint16ToBytes(bitsPerSample)); // Bits per Sample
    header.add(ascii.encode('data')); // Subchunk2 ID
    header.add(_uint32ToBytes(dataSize)); // Subchunk2 Size

    final wavData = BytesBuilder();
    wavData.add(header.toBytes());
    wavData.add(pcmData);

    return wavData.toBytes();
  }

  Uint8List _uint16ToBytes(int value) {
    final bytes = ByteData(2);
    bytes.setUint16(0, value, Endian.little);
    return bytes.buffer.asUint8List();
  }

  Uint8List _uint32ToBytes(int value) {
    final bytes = ByteData(4);
    bytes.setUint32(0, value, Endian.little);
    return bytes.buffer.asUint8List();
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
