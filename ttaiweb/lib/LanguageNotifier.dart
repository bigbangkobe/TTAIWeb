import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageModel {
  final String localName;
  final String languageCode;
  final String countryCode;

  LanguageModel({
    required this.localName,
    required this.languageCode,
    required this.countryCode,
  });

  factory LanguageModel.fromJson(Map<String, dynamic> json) {
    return LanguageModel(
      localName: json['localName'],
      languageCode: json['languageCode'],
      countryCode: json['countryCode'],
    );
  }
}

class LanguageNotifier extends StateNotifier<Locale> {
  LanguageNotifier() : super(Locale('zh', 'CN')) {
    loadLanguages();
    loadSavedLanguage();
  }

  List<LanguageModel> _languages = [];
  Map<String, Locale> _languageMap = {};
  Map<String, String> _languageCodeMap = {};
  String _localName = '中文';
  // 获取系统语言
  Locale systemLocale = WidgetsBinding.instance.window.locale;

  Future<void> loadLanguages() async {
    final jsonString =
    await rootBundle.loadString('assets/lang/languages.json');
    final List<dynamic> jsonData = json.decode(jsonString);
    _languages = jsonData.map((e) => LanguageModel.fromJson(e)).toList();

    // 构建 localName 到 Locale 的映射
    _languageMap = {
      for (var language in _languages)
        language.localName: Locale(language.languageCode, language.countryCode)
    };

    // 构建 localName 到 Locale 的映射
    _languageCodeMap = {
      for (var language in _languages) language.countryCode: language.localName
    };
  }

  List<LanguageModel> get languages => _languages;

  Map<String, Locale> get languageMap => _languageMap;

  String get localName => _localName;

  Future<void> changeLanguage(String localName) async {
    if (_languageMap.containsKey(localName)) {
      state = _languageMap[localName]!;
      await saveLanguage(localName);
    }
  }

  Future<void> saveLanguage(String localName) async {
    _localName = localName;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_language', localName);
  }

  Future<void> loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguage = prefs.getString('selected_language');
    if (savedLanguage != null && _languageMap.containsKey(savedLanguage)) {
      state = _languageMap[savedLanguage]!;
      _localName = savedLanguage.toString();
    }else
    {
      // await _initializeLocale();
      await _setLocaleFromSystemLanguage(systemLocale);
      await prefs.setString('selected_language', _localName);
    }
  }

  // 根据系统语言设置应用的 Locale
  Future<void> _setLocaleFromSystemLanguage(Locale systemLocale) async {
    String? languageCode = systemLocale.countryCode;

    // 假设 _languageCodeMap 是一个映射表，将语言代码映射到你的应用支持的语言
    if (_languageCodeMap.containsKey(languageCode)) {
      // 如果系统语言在支持列表中，设置对应的 Locale
      state = _languageMap[_languageCodeMap[languageCode]]!;
      _localName = _languageCodeMap[languageCode]!;
    }else
    {
      String countryCode = 'US'; // 默认国家为美国
      state = _languageMap[_languageCodeMap[countryCode]]!;
      _localName = _languageCodeMap[countryCode]!;
    }
  }

  // 获取用户当前位置并设置合适的 Locale
  Future<void> _initializeLocale() async {
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    // 根据经纬度获取国家信息
    await _getCountryFromCoordinates(position.latitude, position.longitude);
  }

  // 根据经纬度获取国家信息并设置 Locale
  Future<void> _getCountryFromCoordinates(
      double latitude, double longitude) async {
    // 使用 geocoding 插件进行反向地理编码
    List<Placemark>? placemarks = await GeocodingPlatform.instance
        ?.placemarkFromCoordinates(latitude, longitude);

    if (placemarks!.isNotEmpty) {
      String countryCode = placemarks.first.isoCountryCode ?? 'US'; // 默认国家为美国

      if(_languageCodeMap.containsKey(countryCode))
      {
        state = _languageMap[_languageCodeMap[countryCode]]!;
        _localName = _languageCodeMap[countryCode]!;
      }
    }
  }
}
