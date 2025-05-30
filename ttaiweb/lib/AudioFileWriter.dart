// import 'dart:convert';
// import 'dart:typed_data';
//
// class AudioFileWriter {
//   File? _file;
//   IOSink? _fileSink;
//   bool _isHeaderWritten = false;
//
//   // 保存音频数据的文件路径
//   Future<void> startWriting(String path) async {
//     final filePath = path;
//
//     // 如果文件已经打开，先关闭旧的 sink
//     if (_fileSink != null) {
//       await stopWriting();
//     }
//
//     // Create the file and open the sink for writing
//     _file = File(filePath);
//     _fileSink = _file!.openWrite();
//   }
//
//   // 写入音频数据
//   Future<void> writeAudioData(Uint8List audioData) async {
//     if (_fileSink != null) {
//       if (!_isHeaderWritten) {
//         // 写入WAV头部
//         writeWavHeader(audioData.length);
//         _isHeaderWritten = true;
//       }
//       _fileSink!.add(audioData); // 写入数据
//       await _fileSink!.flush();  // 刷新数据到文件
//     } else {
//       print("Error: _fileSink is null");
//     }
//   }
//
//   // 停止写入，并关闭文件流
//   Future<void> stopWriting() async {
//     if (_fileSink != null) {
//       await _fileSink!.close(); // 关闭文件流
//       _fileSink = null; // 重置_sink，防止再次使用
//       print("Audio file writing stopped.");
//     }
//   }
//
//   // 写入WAV头部信息
//   void writeWavHeader(int dataLength) {
//     final sampleRate = 16000; // 采样率
//     final numChannels = 1; // 单声道
//     final bitsPerSample = 16; // 每个样本的位数
//     final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
//     final blockAlign = numChannels * bitsPerSample ~/ 8;
//
//     // WAV头部信息的字节数组
//     final header = Uint8List(44);
//     header.setAll(0, utf8.encode('RIFF')); // ChunkID
//     header.setRange(4, 8, intToBytes(36 + dataLength, 4)); // ChunkSize
//     header.setAll(8, utf8.encode('WAVE')); // Format
//     header.setAll(12, utf8.encode('fmt ')); // Subchunk1ID
//     header.setRange(16, 20, intToBytes(16, 4)); // Subchunk1Size
//     header.setRange(20, 22, intToBytes(1, 2)); // AudioFormat (PCM = 1)
//     header.setRange(22, 24, intToBytes(numChannels, 2)); // NumChannels
//     header.setRange(24, 28, intToBytes(sampleRate, 4)); // SampleRate
//     header.setRange(28, 32, intToBytes(byteRate, 4)); // ByteRate
//     header.setRange(32, 34, intToBytes(blockAlign, 2)); // BlockAlign
//     header.setRange(34, 36, intToBytes(bitsPerSample, 2)); // BitsPerSample
//     header.setAll(36, utf8.encode('data')); // Subchunk2ID
//     header.setRange(40, 44, intToBytes(dataLength, 4)); // Subchunk2Size
//
//     _fileSink!.add(header); // 写入头部
//   }
//
//   // 将整数转换为字节
//   Uint8List intToBytes(int value, int length) {
//     final bytes = Uint8List(length);
//     for (int i = 0; i < length; i++) {
//       bytes[length - i - 1] = (value >> (i * 8)) & 0xFF;
//     }
//     return bytes;
//   }
// }
