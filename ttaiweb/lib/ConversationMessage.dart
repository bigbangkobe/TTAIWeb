class ConversationMessage {
  final String id;
  String originalText; //原文本
  String translatedText; //翻译文本
  String ttsFilePath; //tts音频路径
  bool isLeft; //是否左边的对话框
  bool isThinking; //是否在思考
  bool isReasoning; //是否在推理
  int thinkSeconds; //思考了多少秒
  PlaybackStatus playbackStatus; //气泡动画状态
  bool isMarkdown;

  ConversationMessage({
    required this.id,
    required this.originalText,
    required this.translatedText,
    required this.ttsFilePath,
    required this.isLeft,
    this.isThinking = false,
    this.isReasoning = false,
    this.thinkSeconds = 0,
    this.playbackStatus = PlaybackStatus.idle,
    this.isMarkdown = true,
  });

  // JSON 序列化
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'originalText': originalText,
      'translatedText': translatedText,
      'ttsFilePath': ttsFilePath,
      'isLeft': isLeft,
      'isThinking': isThinking,
      'isReasoning': isReasoning,
      'thinkSeconds': thinkSeconds,
    };
  }

  // JSON 反序列化
  factory ConversationMessage.fromJson(Map<String, dynamic> json) {
    return ConversationMessage(
      id: json['id'],
      originalText: json['originalText'] ?? '',
      translatedText: json['translatedText'] ?? '',
      ttsFilePath: json['ttsFilePath'] ?? '',
      isLeft: json['isLeft'] ?? false,
      isThinking: json['isThinking'] ?? false,
      isReasoning: json['isReasoning'] ?? false,
      thinkSeconds: json['thinkSeconds'] ?? 0,
      playbackStatus: PlaybackStatus.idle, // 反序列化后默认是 idle
      //  如果模型是豆包大模型，那么isMarkdown=false
      isMarkdown: true,
    );
  }
}

enum PlaybackStatus {
  idle,        // 无状态
  talking,     // 正在录音（说话）
  playing,     // 正在播放
}
