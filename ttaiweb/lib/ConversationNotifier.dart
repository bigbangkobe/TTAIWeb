import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ConversationMessage.dart';

// 管理对话内容的StateNotifier
class ConversationNotifier extends StateNotifier<List<ConversationMessage>> {
  final String storageKey;
  String? playingFilePath; // 当前正在播放的 TTS 文件路径
  ConversationNotifier(this.storageKey) : super([]) {
    _loadMessages();
  }

  // 加载消息数据
  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final messagesJson = prefs.getStringList(storageKey);
    if (messagesJson != null) {
      state = messagesJson
          .map((messageJson) =>
          ConversationMessage.fromJson(jsonDecode(messageJson)))
          .toList();
    }
  }

  // 保存消息数据
  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final messagesJson =
    state.map((message) => jsonEncode(message.toJson())).toList();
    await prefs.setStringList(storageKey, messagesJson);
  }

  // 添加消息
  void addMessage(ConversationMessage message) {
    state = [...state, message];
    _saveMessages();
  }

  // 更新消息
  void updateMessage(ConversationMessage updatedMessage) {
    state = [
      for (final message in state)
        if (message == updatedMessage) updatedMessage else message,
    ];
    _saveMessages();
  }

  void setPlayingFilePath(String? filePath) {
    playingFilePath = filePath;
    state = [...state]; // 触发 UI 更新
  }

  // 删除消息
  void removeMessage(ConversationMessage message) {
    state = state.where((msg) => msg != message).toList();
    _saveMessages();
  }

  void removeThinkingMessage() {
    state = state.where((msg) => !msg.isThinking).toList();
  }

  // 清空对话
  void clearMessages() {
    state = [];
    _saveMessages();
  }

  String toText() {
    final resultBuilder = StringBuffer();

    for (int i = 0; i < state.length; i++) {
      if (state[i].originalText == null || state[i].originalText == "")
        continue;
      resultBuilder.write(state[i].originalText);
      resultBuilder.write("\n");
      if (state[i].translatedText != null && state[i].translatedText != "") {
        resultBuilder.write(state[i].translatedText);
        resultBuilder.write("\n");
      }
    }
    return resultBuilder.toString();
  }

  // Check if a message is already present
  bool containsMessage(ConversationMessage message) {
    return state.contains(message);
  }
}

// // 提供者
// final conversationProvider =
//     StateNotifierProvider<ConversationNotifier, List<ConversationMessage>>(
//   (ref) => ConversationNotifier(),
// );
final conversationProviderAiChat =
StateNotifierProvider<ConversationNotifier, List<ConversationMessage>>(
      (ref) => ConversationNotifier('conversationProviderAiChat'),
);
final conversationProviderTranslate =
StateNotifierProvider<ConversationNotifier, List<ConversationMessage>>(
      (ref) => ConversationNotifier('conversationProviderTranslate'),
);
final conversationProviderTranslateUseHeadset =
StateNotifierProvider<ConversationNotifier, List<ConversationMessage>>(
      (ref) => ConversationNotifier('conversationProviderTranslateUseHeadset'),
);
final conversationProviderTranslateBinaural =
StateNotifierProvider<ConversationNotifier, List<ConversationMessage>>(
      (ref) => ConversationNotifier('conversationProviderTranslateBinaural'),
);
final conversationProviderRecording =
StateNotifierProvider<ConversationNotifier, List<ConversationMessage>>(
      (ref) => ConversationNotifier('conversationProviderRecording'),
);
