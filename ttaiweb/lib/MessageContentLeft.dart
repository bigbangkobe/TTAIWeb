import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class MessageContentLeft extends StatelessWidget {
  final String originalText;
  final String translatedText;
  final String ttsFilePath;
  final bool isTalking;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onStop;
  final String? playingFilePath;
  final Color? originalTextColor;
  // 是否自动播放语音
  final bool isAutoPlaying;

  const MessageContentLeft({
    super.key,
    required this.originalText,
    required this.translatedText,
    required this.ttsFilePath,
    required this.playingFilePath,
    required this.isPlaying,
    required this.isTalking,
    required this.onPlay,
    required this.onStop,
    required this.originalTextColor,
    // 是否自动播放语音
    // required this.isAutoPlaying,
    this.isAutoPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    bool isPlaying = playingFilePath == ttsFilePath; // 判断是否在播放当前消息
    // bool isCurrentlyPlaying = playingFilePath == ttsFilePath && (isPlaying || isAutoPlaying);
    return Padding(
      padding: const EdgeInsets.only(bottom: 1.0, top: 1.0, right: 15.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 用户头像
          // Container(
          //   width: 33.5,
          //   height: 33.5,
          //   margin: const EdgeInsets.only(right: 8.0),
          //   decoration: BoxDecoration(
          //     shape: BoxShape.circle,
          //     image: DecorationImage(
          //       image: AssetImage('assets/images/ic_user_head_icon.png'),
          //       fit: BoxFit.cover,
          //     ),
          //   ),
          // ),
          // 消息内容容器
          Flexible(
            child: IntrinsicWidth(
              child: Container(
                  padding: const EdgeInsets.fromLTRB(14.5, 3, 18.5, 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start, // 确保从顶部开始布局
                    children: [
                      // 录音动画
                      if (isTalking && originalText.isEmpty)
                        Image.asset(
                          'assets/animations/message_recordinggif.gif',
                          width: 42,
                          height: 11.5,
                        ),

                      // 原文本
                      if (originalText.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 1.0), // 减少顶部的间距
                          child: Text(
                            originalText,
                            style: TextStyle(
                              color: originalTextColor ?? Color(0xFF333333),
                              fontSize: 16,
                            ),
                            softWrap: true,
                            overflow: TextOverflow.visible,
                          ),
                        ),

                      // 分隔线
                      if (translatedText.isNotEmpty)
                        const Divider(
                          height: 8, // 减少分隔线的高度
                          color: Colors.grey,
                          thickness: 0.5,
                        ),

                      // 翻译文本
                      if (translatedText.isNotEmpty)
                        Text(
                          translatedText,
                          style: const TextStyle(
                            color: Color(0xFF333333),
                            fontSize: 16,
                          ),
                          softWrap: true,
                          overflow: TextOverflow.visible,
                        ),

                      // 播放和停止按钮
                      if (ttsFilePath.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min, // 确保只占用必要空间
                          children: [
                            GestureDetector(
                              // 点击语音播报按钮后，不再继续朗读后面翻译的内容，且播放动画还在
                              onTap: isPlaying || isAutoPlaying ? onStop : onPlay, // 点击时触发事件
                              // onTap: () {
                              //   if (isPlaying || isAutoPlaying) {
                              //     onStop();
                              //   } else {
                              //     onPlay();
                              //   }
                              // },
                              child: Image.asset(
                                isPlaying || isAutoPlaying
                                    ? 'assets/images/ic_message_stop.png' // Pause icon
                                    : 'assets/images/ic_message_play.png', // Play icon
                                width: 20,
                                height: 20,
                              ),
                            ),
                            SizedBox(
                              width: 5,
                            ),
                            if (isPlaying || isAutoPlaying)
                              Image.asset(
                                'assets/animations/messageitemvoicegif.gif',
                                width: 77,
                                height: 15,
                              ),
                          ],
                        ),
                    ],
                  )),
            ),
          ),
        ],
      ),
    );
  }
}
