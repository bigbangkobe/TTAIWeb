import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:web_socket_channel/html.dart';
import 'package:universal_html/html.dart' as html;

class XunFeiTTS {
  // —— 配置部分 —— //
  static const _wsBase    = 'wss://tts-api.xfyun.cn/v2/tts';
  static const _httpBase  = 'https://tts-api.xfyun.cn/v2/tts';
  static const _appId     = 'b32dc8bb';
  static const _apiKey    = '0767a26bf47c15e6f701f9df9b9793e0';
  static const _apiSecret = 'MjRhNTRhM2MyNWEyZDNjZThjZjRlMjM2';

  HtmlWebSocketChannel? _channel;
  final List<Uint8List> _chunks = [];

  /// 主动开始 TTS 合成并播放
  Future<void> startTTS({
    required String text,
    String vcn = 'xiaoyan',
    VoidCallback? onDone,
  }) async {
    _chunks.clear();

    // 1. 时间戳
    final date = _rfc1123Date();
    print('emmmmmm date = $date text = $text');

    // 2. 签名源串
    final uri    = Uri.parse(_httpBase);
    final origin = 'host: ${uri.host}\n'
        'date: $date\n'
        'GET ${uri.path} HTTP/1.1';
    print('emmmmmm origin:\n$origin');

    // 3. 生成 signature
    final signature = base64.encode(
        Hmac(sha256, utf8.encode(_apiSecret))
            .convert(utf8.encode(origin))
            .bytes
    );
    print('emmmmmm signature = $signature');

    // 4. 构造 authorization
    final authOrigin = 'api_key="$_apiKey",'
        'algorithm="hmac-sha256",'
        'headers="host date request-line",'
        'signature="$signature"';
    final authorization = base64.encode(utf8.encode(authOrigin));
    print('emmmmmm authorization = $authorization');

    // 5. 构造并打印 wsUri
    final wsUri = Uri.parse(_wsBase).replace(queryParameters: {
      'authorization': authorization,
      'date':          date,
      'host':          uri.host,
    });
    print('emmmmmm wsUri = $wsUri');

    // 6. 连接
    _channel = HtmlWebSocketChannel.connect(wsUri.toString());
    print('emmmmmm connecting to WebSocket…');

    // 7. 接收消息
    _channel!.stream.listen((frame) {
      print('emmmmmm raw frame: $frame');

      final msg = jsonDecode(frame as String) as Map<String, dynamic>;
      print('emmmmmm code=${msg['code']} message=${msg['message']}');

      if (msg['code'] != 0) {
        print('emmmmmm server error, closing');
        _channel?.sink.close();
        return;
      }

      if (msg.containsKey('sid')) {
        print('emmmmmm sid=${msg['sid']}');
      }

      final data = msg['data'] as Map<String, dynamic>?;
      if (data == null) {
        print('emmmmmm data is null, skip');
        return;
      }

      final status = data['status'];
      final ced    = data['ced'];
      final audioB64 = data['audio'] as String?;
      print('emmmmmm status=$status ced=$ced audio.len=${audioB64?.length ?? 0}');

      if (audioB64 != null && audioB64.isNotEmpty) {
        final chunk = base64Decode(audioB64);
        print('emmmmmm decoded chunk.len=${chunk.length}');
        _chunks.add(chunk);
      }

      if (status == 2) {
        print('emmmmmm synthesis finished, total chunks=${_chunks.length}');
        _channel?.sink.close();
        _playAll(onDone);
      }
    }, onError: (e) {
      print('emmmmmm WebSocket error: $e');
    });

    // 8. 发送请求
    final req = {
      'common':  {'app_id': _appId},
      'business': {
        'aue':   'lame',
        'sfl':   1,
        'vcn':   vcn,
        'speed': 50,
        'pitch': 50,
        'volume':50,
        'tte':   'UTF8',
      },
      'data': {
        'status': 2,
        'text':   base64Encode(utf8.encode(text)),
      },
    };
    print('emmmmmm send req: ${jsonEncode(req)}');
    _channel!.sink.add(jsonEncode(req));
  }

  /// 拼接所有音频分片并在浏览器中播放
  void _playAll(VoidCallback? onDone) {
    final totalLen = _chunks.fold<int>(0, (sum, c) => sum + c.length);
    final bytes    = Uint8List(totalLen);
    var offset = 0;
    for (var chunk in _chunks) {
      bytes.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }

    final blob   = html.Blob([bytes], 'audio/mpeg');
    final url    = html.Url.createObjectUrlFromBlob(blob);
    final player = html.AudioElement(url)
      ..autoplay = true
      ..onEnded.listen((_) {
        html.Url.revokeObjectUrl(url);
        onDone?.call();
      });
    player.play();

    // // 2. 触发浏览器下载，文件名为 tts_output.mp3
    // final anchor = html.AnchorElement(href: url)
    //   ..setAttribute('download', 'tts_output.mp3')
    //   ..style.display = 'none';
    // html.document.body!.append(anchor);
    // anchor.click();
    // anchor.remove();

    print('emmmmmm TTS 音频已触发下载，文件名：tts_output.mp3');
  }

  /// 显式停止，关闭 WebSocket（无法中断已经开始的 Audio 播放）
  void stop() {
    _channel?.sink.close();
  }

  /// 生成 RFC1123 格式的 UTC 时间字符串
  String _rfc1123Date() {
    final now = DateTime.now().toUtc();
    const wkday = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    const mont  = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final wd  = wkday[now.weekday - 1];
    final m   = mont[now.month   - 1];
    final d   = now.day           .toString().padLeft(2, '0');
    final h   = now.hour          .toString().padLeft(2, '0');
    final min = now.minute        .toString().padLeft(2, '0');
    final s   = now.second        .toString().padLeft(2, '0');
    return '$wd, $d $m ${now.year} $h:$min:$s GMT';
  }
}
