import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'ConversationMessage.dart';

class MessageContentLeft extends StatelessWidget {
  final String originalText;
  final String translatedText;
  final String ttsFilePath;
  final PlaybackStatus playbackStatus;
  final VoidCallback onPlay;
  final VoidCallback onStop;
  final Color? originalTextColor;

  const MessageContentLeft({
    super.key,
    required this.originalText,
    required this.translatedText,
    required this.ttsFilePath,
    required this.playbackStatus,
    required this.onPlay,
    required this.onStop,
    this.originalTextColor,
  });

  bool get isPlaying => playbackStatus == PlaybackStatus.playing;
  bool get isTalking => playbackStatus == PlaybackStatus.talking;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 1.0, top: 1.0, right: 15.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  children: [
                    if (isTalking && originalText.isEmpty)
                      _buildTalkingAnimation(),

                    if (originalText.isNotEmpty)
                      _buildOriginalText(),

                    if (translatedText.isNotEmpty) ...[
                      const Divider(
                        height: 8,
                        color: Colors.grey,
                        thickness: 0.5,
                      ),
                      _buildTranslatedText(),
                    ],
                    _buildPlaybackControls(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTalkingAnimation() {
    return Image.asset(
      'assets/animations/message_recordinggif.gif',
      width: 42,
      height: 11.5,
    );
  }

  Widget _buildOriginalText() {
    return Padding(
      padding: const EdgeInsets.only(top: 1.0),
      child: Text(
        originalText,
        style: TextStyle(
          color: originalTextColor ?? const Color(0xFF333333),
          fontSize: 16,
        ),
        softWrap: true,
        overflow: TextOverflow.visible,
      ),
    );
  }

  Widget _buildTranslatedText() {
    return Text(
      translatedText,
      style: const TextStyle(
        color: Color(0xFF333333),
        fontSize: 16,
      ),
      softWrap: true,
      overflow: TextOverflow.visible,
    );
  }

  Widget _buildPlaybackControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (ttsFilePath.isNotEmpty)
          GestureDetector(
            onTap: isPlaying ? onStop : onPlay,
            child: Image.asset(
              isPlaying
                  ? 'assets/images/ic_message_stop.png'
                  : 'assets/images/ic_message_play.png',
              width: 20,
              height: 20,
            ),
          ),
        const SizedBox(width: 5),
        if (isPlaying)
          Image.asset(
            'assets/animations/messageitemvoicegif.gif',
            width: 77,
            height: 15,
          ),
      ],
    );
  }
}