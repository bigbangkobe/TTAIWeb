
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ttaiweb/JoinViewPage.dart';
import 'AnalyticsObserver.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 获取 URL 中的 `agoraChannelId` 参数
    ZegoConfig.instance.userID = Uri.base.queryParameters['userId']!;
    ZegoConfig.instance.userName = Uri.base.queryParameters['userName']!;
    ZegoConfig.instance.room = Uri.base.queryParameters['room']!;
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
