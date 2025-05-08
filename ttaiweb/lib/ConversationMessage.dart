class ConversationMessage {
  String originalText;
  String translatedText;
  String ttsFilePath;
  bool isTalking;
  bool isPlaying;
  bool isLeft;
  bool isThinking;
  bool isReasoning;
  int thinkSeconds;
  // 是否自动播放语音
  bool isAutoPlaying;

  ConversationMessage({
    required this.originalText,
    required this.translatedText,
    required this.ttsFilePath,
    required this.isPlaying,
    required this.isTalking,
    required this.isLeft,
    this.isThinking = false,
    this.isReasoning = false,
    this.thinkSeconds = 0,
    // 是否自动播放语音
    this.isAutoPlaying = false,
  });

  // 将ConversationMessage转换为JSON格式
  Map<String, dynamic> toJson() {
    return {
      'originalText': originalText,
      'translatedText': translatedText,
      'ttsFilePath': ttsFilePath,
      'isTalking': isTalking,
      'isPlaying': isPlaying,
      'isLeft': isLeft,
      'isReasoning': isReasoning,
      'thinkSeconds': thinkSeconds,
    };
  }

  // 从JSON中反序列化为ConversationMessage对象
  factory ConversationMessage.fromJson(Map<String, dynamic> json) {
    return ConversationMessage(
      originalText: json['originalText'],
      translatedText: json['translatedText'],
      ttsFilePath: json['ttsFilePath'],
      isTalking: false,
      isPlaying: false,
      isLeft: json['isLeft'],
      isReasoning: json['isReasoning'],
      thinkSeconds: json['thinkSeconds'],
    );
  }
}
