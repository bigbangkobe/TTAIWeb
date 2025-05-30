// import 'dart:typed_data';
// import 'dart:ui';
// import 'package:flutter_sound/flutter_sound.dart';
// import 'dart:io';
//
// class AudioPlayerUtil {
//   final FlutterSoundPlayer _player = FlutterSoundPlayer();
//   bool isPlaying = false;
//
//   AudioPlayerUtil() {
//     _player.openPlayer();
//   }
//
//   // 修改 playPCMFromFile，接受一个回调参数
//   Future<void> playPCMFromFile(
//       String filePath, VoidCallback onPlayCompletedCallback) async {
//     try {
//       if (isPlaying) {
//         stop();
//       }
//       isPlaying = true;
//
//
//       File file = File(filePath);
//       Uint8List pcmData = await file.readAsBytes();
//
//       // 播放 PCM 数据并等待播放完成
//       await _player.startPlayer(
//         fromDataBuffer: pcmData,
//         codec: Codec.pcm16,
//         whenFinished: () async {
//           await onPlayCompleted(onPlayCompletedCallback); // 使用内联回调
//         },
//       );
//     } catch (e) {
//       print('Error playing PCM file: $e');
//       await stop(); // 错误时确保释放音频焦点和停止播放
//     }
//   }
//
//   Future<void> playPCMFromFileTwoSoundChannel(String filePath,
//       VoidCallback onPlayCompletedCallback, bool ifLeft) async {
//     try {
//       if (isPlaying) {
//         stop();
//       }
//       isPlaying = true;
//
//       File file = File(filePath);
//       Uint8List pcmData = await file.readAsBytes();
//
//       int numSamples = pcmData.length ~/ 2;
//
//       // 解析 16-bit PCM 数据
//       Int16List monoSamples =
//       Int16List.sublistView(pcmData.buffer.asInt16List());
//
//       // 转换为双声道，根据语言选择声道
//       List<int> stereoSamples = [];
//       for (int i = 0; i < numSamples; i++) {
//         if (!ifLeft) {
//           stereoSamples.add(0); // 左声道静音
//           stereoSamples.add(monoSamples[i]); // 右声道
//
//           // 插值增加采样率（简单复制插值）
//           stereoSamples.add(0); // 左声道静音插值
//           stereoSamples.add(monoSamples[i]); // 右声道插值
//         } else {
//           stereoSamples.add(monoSamples[i]); // 左声道
//           stereoSamples.add(0); // 右声道静音
//
//           // 插值增加采样率（简单复制插值）
//           stereoSamples.add(monoSamples[i]); // 左声道插值
//           stereoSamples.add(0); // 右声道静音插值
//         }
//       }
//
//       // // 播放 PCM 数据并等待播放完成
//       // await _player.startPlayer(
//       //   fromDataBuffer: Int16List.fromList(stereoSamples).buffer.asUint8List(),
//       //   codec: Codec.pcm16,
//       //   sampleRate: 32000, // 采样率 32kHz
//       //   numChannels: 2, // 双声道
//       //   whenFinished: () async {
//       //     await onPlayCompleted(onPlayCompletedCallback); // 使用内联回调
//       //   },
//       // );
//
//       //     // 转换为双声道音频数据
//       // List<int> stereoSamples = [];
//       // for (int i = 0; i < numSamples; i++) {
//       //   if (!ifLeft) {
//       //     stereoSamples.add(0); // 左声道静音
//       //     stereoSamples.add(monoSamples[i]); // 右声道
//       //   } else {
//       //     stereoSamples.add(monoSamples[i]); // 左声道
//       //     stereoSamples.add(0); // 右声道静音
//       //   }
//       // }
//
//       // 获取平台信息，调整音频设置
//       if (Platform.isAndroid) {
//         // Android上直接使用32kHz
//         await _player.startPlayer(
//           fromDataBuffer: Int16List.fromList(stereoSamples).buffer.asUint8List(),
//           codec: Codec.pcm16,
//           sampleRate: 32000, // 采样率 32kHz
//           numChannels: 2, // 双声道
//           whenFinished: () async {
//             await onPlayCompleted(onPlayCompletedCallback); // 使用内联回调
//           },
//         );
//       } else if (Platform.isIOS) {
//         // iOS上尝试使用48kHz采样率
//         print("Playing audio with 48kHz on iOS");
//
//         await _player.startPlayer(
//           fromDataBuffer: Int16List.fromList(stereoSamples).buffer.asUint8List(),
//           codec: Codec.pcm16,
//           sampleRate: 32000, // 使用更常见的 48kHz 采样率
//           numChannels: 2, // 双声道
//           whenFinished: () async {
//             await onPlayCompleted(onPlayCompletedCallback); // 使用内联回调
//           },
//         );
//       }
//     } catch (e) {
//       print('Error playing PCM file: $e');
//       await stop(); // 错误时确保释放音频焦点和停止播放
//     }
//   }
//
//   // 播放 MP3 文件
//   Future<void> playMP3FromFile(
//       String filePath, VoidCallback onPlayCompletedCallback) async {
//     try {
//       if (isPlaying) {
//         stop();
//       }
//       isPlaying = true;
//
//       // 播放 MP3 文件
//       await _player.startPlayer(
//         fromURI: filePath,
//         codec: Codec.mp3,
//         whenFinished: () async {
//           await onPlayCompleted(onPlayCompletedCallback);
//         },
//       );
//     } catch (e) {
//       print('Error playing MP3 file: $e');
//       await stop();
//     }
//   }
//
//   // 播放完成后的清理操作
//   Future<void> onPlayCompleted(VoidCallback onPlayCompletedCallback) async {
//     if (isPlaying) {
//       isPlaying = false;
//       onPlayCompletedCallback.call(); // 调用外部传入的回调
//     }
//   }
//
//   // 停止播放并丢弃音频焦点
//   Future<void> stop() async {
//     if (isPlaying) {
//       isPlaying = false;
//       await _player.stopPlayer(); // 停止播放器
//     }
//   }
//
//   // 释放播放器资源
//   void dispose() {
//     _player.closePlayer();
//   }
// }
