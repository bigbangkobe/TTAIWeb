
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ttaiweb/JoinViewPage.dart';
import 'AnalyticsObserver.dart';
import 'LanguageManager.dart';
import 'ZegoUntils.dart';

void main() async {
  // 确保初始化 Flutter 绑定
  WidgetsFlutterBinding.ensureInitialized();

  // 处理系统UI设置
  SystemChrome.setApplicationSwitcherDescription(
    ApplicationSwitcherDescription(
      label: "TTAI",
      primaryColor: 0xFF000000, // 保持颜色
    ),
  );

  // 设置只支持竖屏（正竖屏和倒竖屏）
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(
    ProviderScope(
      // 初始化 Riverpod
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  final RouteObserver<PageRoute<dynamic>> routeObserver = AnalyticsObserver();

  void parseShareLink() {
    final encodedData = Uri.base.queryParameters['data'];

    if (encodedData == null) {
      throw Exception("分享链接缺少 data 参数！");
    }

    try {
      final decodedJson = utf8.decode(base64Url.decode(encodedData));
      final params = jsonDecode(decodedJson);

      ZegoConfig.instance.userID = params['userId'];
      ZegoConfig.instance.userName = params['userName'];
      ZegoConfig.instance.room = params['room'];
      ZegoConfig.instance.leftLanguageIndex = params['leftLanguageIndex'];
      ZegoConfig.instance.rightLanguageIndex = params['rightLanguageIndex'];
      print("userId:" + params['userId'] + ",userName:" + params['userName'] + ",room:" + params['room'] +
          ",leftLanguageIndex:" + params['leftLanguageIndex'] + ",rightLanguageIndex:" + params['rightLanguageIndex']
      );
    } catch (e) {
      print("分享链接解码失败：$e");
    }
  }


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 获取 URL 中的 `agoraChannelId` 参数
    parseShareLink();

    Future.microtask(() {
      final not = ref
          .read(languageSelectionProvider(
          "VedioCall")
          .notifier);
      not.selectLeftLanguage(ZegoConfig.instance.rightLanguageIndex);
      not.selectRightLanguage(ZegoConfig.instance.leftLanguageIndex);
    });
    // agoraChannelId = channelId!;
    return MaterialApp(
      navigatorObservers: [routeObserver],
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white, // 设置与状态栏一致的背景色
      ),
      home: JoinViewPage(), // 将 agoraChannelId 传递给 JoinViewPage
    );
  }
}
