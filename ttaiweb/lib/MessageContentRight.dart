import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class MessageContentRight extends StatelessWidget {
  final String originalText;
  final String translatedText;
  final String ttsFilePath;
  final String? playingFilePath;
  final bool isTalking;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onStop;
  // 是否自动播放语音
  final bool isAutoPlaying;

  const MessageContentRight({
    super.key,
    required this.originalText,
    required this.translatedText,
    required this.ttsFilePath,
    required this.playingFilePath,
    required this.isPlaying,
    required this.isTalking,
    required this.onPlay,
    required this.onStop,
    // 是否自动播放语音
    this.isAutoPlaying = false,
    // required this.isAutoPlaying,
  });

  @override
  Widget build(BuildContext context) {
    bool isPlaying = playingFilePath == ttsFilePath; // 判断是否在播放当前消息
    return Padding(
      padding: const EdgeInsets.only(bottom: 1.0, top: 1.0, left: 15.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // 消息内容容器
          Flexible(
            child: IntrinsicWidth(
              child: Container(
                padding: const EdgeInsets.fromLTRB(14.5, 3, 18.5, 10),
                decoration: BoxDecoration(
                  // color: Color(0xFF4D6EF3),
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(30.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 录音动画
                    if (isTalking && originalText.isEmpty)
                      Image.asset(
                        'assets/animations/message_recording_white_gif.gif',
                        width: 42,
                        height: 11.5,
                      ),

                    // 原文本
                    if (originalText.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 1.0),
                        child: Text(
                          originalText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          softWrap: true,
                          overflow: TextOverflow.visible,
                        ),
                      ),

                    // 分隔线
                    if (translatedText.isNotEmpty)
                      const Divider(
                        height: 10,
                        color: Colors.white,
                        thickness: 0.5,
                      ),

                    // 翻译文本
                    if (translatedText.isNotEmpty)
                      Text(
                        translatedText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        softWrap: true,
                        overflow: TextOverflow.visible,
                      ),

                    // 播放和停止按钮
                    if (ttsFilePath.isNotEmpty)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GestureDetector(
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
                                  ? 'assets/images/ic_message_stop.png'
                                  : 'assets/images/ic_message_play.png',
                              width: 20,
                              height: 20,
                            ),
                          ),
                          SizedBox(
                            width: 5,
                          ),
                          if (isPlaying || isAutoPlaying)
                            Image.asset(
                              'assets/animations/messageitemvoicegif_white.gif',
                              width: 77,
                              height: 15,
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),

          // 用户头像
          // Container(
          //   width: 33.5,
          //   height: 33.5,
          //   margin: const EdgeInsets.only(left: 8.0),
          //   decoration: BoxDecoration(
          //     shape: BoxShape.circle,
          //     image: DecorationImage(
          //       image: AssetImage('assets/images/ic_user_head_icon.png'),
          //       fit: BoxFit.cover,
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }
}
