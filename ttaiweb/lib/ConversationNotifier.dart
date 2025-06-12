import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'ConversationMessage.dart';

// 管理对话内容的StateNotifier
class ConversationNotifier extends StateNotifier<List<ConversationMessage>> {
  final String storageKey;


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
  /// 更新消息内容，根据 [silent] 控制是否刷新 UI（默认为刷新 UI）
  void updateMessage(ConversationMessage updatedMessage, {bool silent = false}) {
    final currentList = silent ? state : List.of(state); // 避免重建引用

    for (int i = 0; i < currentList.length; i++) {
      if (currentList[i].id == updatedMessage.id) {
        currentList[i] = updatedMessage;
        break;
      }
    }

    if (!silent) {
      state = currentList; // 触发 UI 更新
    }

    _saveMessages();
  }

  /// 仅更新消息的播放状态（UI 用）
  void setPlaybackStatus(String id, PlaybackStatus status) {
    state = [
      for (final msg in state)
        if (msg.id == id)
          ConversationMessage(
            id: msg.id,
            originalText: msg.originalText,
            translatedText: msg.translatedText,
            ttsFilePath: msg.ttsFilePath,
            isLeft: msg.isLeft,
            isThinking: msg.isThinking,
            isReasoning: msg.isReasoning,
            thinkSeconds: msg.thinkSeconds,
            playbackStatus: status,
          )
        else
          msg,
    ];
  }

  // 删除消息
  void removeMessage(ConversationMessage message) {
    state = state.where((msg) => msg != message).toList();
    _saveMessages();
  }

  /// 删除指定消息
  void removeMessageById(String id) {
    state = state.where((msg) => msg.id != id).toList();
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

  /// 导出文本格式
  String toText() {
    final buffer = StringBuffer();
    for (final msg in state) {
      if (msg.originalText.trim().isNotEmpty) {
        buffer.writeln(msg.originalText);
        if (msg.translatedText.trim().isNotEmpty) {
          buffer.writeln(msg.translatedText);
        }
      }
    }
    return buffer.toString();
  }

  /// 判断是否已存在同 ID 消息
  bool containsMessage(String id) {
    return state.any((msg) => msg.id == id);
  }

  void updatePlaybackStatus({
    required String id,
    required PlaybackStatus status,
    String? ttsFilePath,
  }) {
    state = [
      for (final msg in state)
        if (msg.id == id)
          ConversationMessage(
            id: msg.id,
            originalText: msg.originalText,
            translatedText: msg.translatedText,
            ttsFilePath: ttsFilePath ?? msg.ttsFilePath,
            isLeft: msg.isLeft,
            isThinking: msg.isThinking,
            isReasoning: msg.isReasoning,
            thinkSeconds: msg.thinkSeconds,
            playbackStatus: status,
          )
        else
          msg,
    ];
  }

  void resetPlaybackStatus()
  {
    for (final msg in state)
      msg.playbackStatus = PlaybackStatus.idle;
  }
}


class MessageIdGenerator {
  static final _uuid = Uuid();
  static String generate() => _uuid.v4();
}


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
final conversationProviderFaceToFaceTranslate =
StateNotifierProvider<ConversationNotifier, List<ConversationMessage>>(
      (ref) => ConversationNotifier('conversationProviderFaceToFaceTranslate'),
);
