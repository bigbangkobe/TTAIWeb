import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    AppLocalizations localizations = AppLocalizations(Locale('zh', 'CN'));
    return localizations;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
  _AppLocalizationsDelegate();

  Map<String, String> _localizedStrings = {};
  Map<String, String> _specialLocalizedStrings = {};

  Future<bool> load() async {
    try {
      specialLoad();
      // 尝试加载指定语言的文件
      String jsonString =
      await rootBundle.loadString('assets/lang/${locale}.json');
      Map<dynamic, dynamic> jsonMap = json.decode(jsonString);
      _localizedStrings = {};
      jsonMap.forEach((key, value) {
        if (key is String && value is String) {
          _localizedStrings[key] = value;
        }
      });
      return true;
    } catch (e) {
      // 如果指定语言的文件不存在，加载默认的 en_US.json
      String defaultJsonString =
      await rootBundle.loadString('assets/lang/en_US.json');
      Map<dynamic, dynamic> defaultJsonMap = json.decode(defaultJsonString);
      _localizedStrings = {};
      defaultJsonMap.forEach((key, value) {
        if (key is String && value is String) {
          _localizedStrings[key] = value;
        }
      });
      return true;
    }
  }

  String translate(String key) {
    return _localizedStrings[key] ?? '$key';
  }

  String specialLocalizedStrings(String key) {
    if (locale.toString() == 'zh_CN') {
      return key;
    }
    return _specialLocalizedStrings[key] ?? '$key';
  }

  Future<void> specialLoad() async {
    String path = '';
    if (locale.toString() == 'zh_TW') {
      path = 'TW';
    } else {
      path = 'US';
    }
    String jsonString = await rootBundle
        .loadString('assets/lang/special_${path}.json');
    Map<dynamic, dynamic> jsonMap = json.decode(jsonString);
    _specialLocalizedStrings = {};
    jsonMap.forEach((key, value) {
      if (key is String && value is String) {
        _specialLocalizedStrings[key] = value;
      }
    });
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    // List of supported language codes
    final supportedLanguageCodes = [
      'zh',
      'en',
      'ja',
      'ru',
      'fr',
      'es',
      'it',
      'vi',
      'th',
      'ko',
      'de',
      'fil',
      'ms',
      'id',
      'ar',
      'tr',
      'kk',
      'af',
      'am',
      'az',
      'bn',
      'ca',
      'cs',
      'da',
      'el',
      'fa',
      'fi',
      'he',
      'hi',
      'hr',
      'hu',
      'hy',
      'is',
      'ro',
      'ka',
      'km',
      'lo',
      'lt',
      'lv',
      'ml',
      'mr',
      'nb',
      'ne',
      'nl',
      'pl',
      'pt',
      'si',
      'sk',
      'sl',
      'sr',
      'su',
      'sv',
      'sw',
      'ta',
      'te',
      'jv',
      'uk',
      'ur',
      'zu',
      'mn',
      'my',
      'ps',
      'ha',
      'uz',
      'tk',
      'tg',
      'bg',
    ];
    return supportedLanguageCodes.contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    AppLocalizations localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(LocalizationsDelegate<AppLocalizations> old) => false;
}
