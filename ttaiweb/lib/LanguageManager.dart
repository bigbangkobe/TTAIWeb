import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

// 静态语言管理类
class LanguageManager {
  static List<Map<String, dynamic>> languages = [];
  static int leftSelectedIndex = 0;
  static int rightSelectedIndex = 1;
  static int aiLanguageSelectedIndex = 0;

  static void setLanguages(List<Map<String, dynamic>> newLanguages) {
    languages = newLanguages;
  }

  static Map<String, dynamic> getLanguage(int index) {
    return (index >= 0 && index < languages.length) ? languages[index] : {};
  }

  static String getCNVoice() {
    return languages.firstWhere((lang) => lang['code'] == 'cn',
        orElse: () => {})['voice'] ??
        "";
  }

  static String getENVoice() {
    return languages.firstWhere((lang) => lang['code'] == 'en',
        orElse: () => {})['voice'] ??
        "";
  }
}

// 语言管理状态
class LanguageState {
  final List<Map<String, dynamic>> languages;
  final int leftLanguageIndex;
  final int rightLanguageIndex;
  final int aiLanguageIndex;

  LanguageState({
    required this.languages,
    this.leftLanguageIndex = 0,
    this.rightLanguageIndex = 1,
    this.aiLanguageIndex = 0,
  });

  Map<String, dynamic> getLanguage(int index) {
    return (index >= 0 && index < languages.length) ? languages[index] : {};
  }

  Map<String, dynamic> getAiLanguage() {
    return getLanguage(aiLanguageIndex);
  }

  LanguageState copyWith({
    List<Map<String, dynamic>>? languages,
    int? rightLanguageIndex,
    int? leftLanguageIndex,
    int? aiLanguageIndex,
  }) {
    return LanguageState(
      languages: languages ?? this.languages,
      rightLanguageIndex: rightLanguageIndex ?? this.rightLanguageIndex,
      leftLanguageIndex: leftLanguageIndex ?? this.leftLanguageIndex,
      aiLanguageIndex: aiLanguageIndex ?? this.aiLanguageIndex,
    );
  }
}

// 使用 Riverpod 提供语言列表
final languageProvider =
StateNotifierProvider<LanguageNotifier, AsyncValue<LanguageState>>(
      (ref) => LanguageNotifier(),
);

class LanguageNotifier extends StateNotifier<AsyncValue<LanguageState>> {
  LanguageNotifier() : super(const AsyncValue.loading()) {
    loadLanguages("languages"); // 确保加载
  }

  String _isInitialized = '';

  Future<void> loadLanguages(String languageFile) async {
    if (_isInitialized == languageFile) return;
    try {
      String data =
      await rootBundle.loadString('assets/configs/$languageFile.json');
      List<dynamic> jsonResult = json.decode(data);
      List<Map<String, dynamic>> parsedLanguages =
      jsonResult.map((e) => Map<String, dynamic>.from(e)).toList();

      state = AsyncValue.data(LanguageState(languages: parsedLanguages));
      LanguageManager.setLanguages(parsedLanguages); // 同步静态类
      _isInitialized = languageFile;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

// 每个页面都有自己的语言管理
final languageSelectionProvider = StateNotifierProvider.family<
    LanguageSelectionNotifier, LanguageState, String>(
      (ref, pageKey) => LanguageSelectionNotifier(ref),
);

class LanguageSelectionNotifier extends StateNotifier<LanguageState> {
  final Ref ref;

  LanguageSelectionNotifier(this.ref) : super(LanguageState(languages: [])) {
    _initializeLanguages();
  }

  void _initializeLanguages() {
    final languageState = ref.read(languageProvider);
    if (languageState is AsyncData) {
      state = LanguageState(languages: languageState.value!.languages);
    }

    // 监听 languageProvider 变化
    ref.listen<AsyncValue<LanguageState>>(languageProvider, (prev, next) {
      if (next is AsyncData) {
        state = state.copyWith(languages: next.value?.languages);
      }
    });
  }

  void selectLeftLanguage(int index) {
    print("selectRightLanguage: $index");
    state = state.copyWith(leftLanguageIndex: index);
    print("321selectRightLanguage: ${state.rightLanguageIndex}");
    LanguageManager.leftSelectedIndex = index;
  }

  void selectRightLanguage(int index) {
    print("selectRightLanguage: $index");
    print("333selectRightLanguage: ${state.leftLanguageIndex}");
    print("444selectRightLanguage: ${state.rightLanguageIndex}");
    state = state.copyWith(rightLanguageIndex: index);
    print("555selectRightLanguage: ${state.leftLanguageIndex}");
    print("666selectRightLanguage: ${state.rightLanguageIndex}");
    LanguageManager.rightSelectedIndex = index;
  }

  void selectAiLanguage(int index) {
    state = state.copyWith(aiLanguageIndex: index);
    LanguageManager.aiLanguageSelectedIndex = index;
  }

  void swapLanguages() {
    state = state.copyWith(
      leftLanguageIndex: state.rightLanguageIndex,
      rightLanguageIndex: state.leftLanguageIndex,
    );

    int temp = LanguageManager.leftSelectedIndex;
    LanguageManager.leftSelectedIndex = LanguageManager.rightSelectedIndex;
    LanguageManager.rightSelectedIndex = temp;
  }

  // 获取当前左侧语言
  Map<String, dynamic> getLeftSelectedLanguage() {
    return state.getLanguage(state.leftLanguageIndex);
  }

  // 获取当前右侧语言
  Map<String, dynamic> getRightSelectedLanguage() {
    return state.getLanguage(state.rightLanguageIndex);
  }

  // 获取 AI 语言
  Map<String, dynamic> getAiLanguage() {
    return state.getAiLanguage();
  }

  int getAiLanguageIndex() {
    return state.aiLanguageIndex;
  }
}
