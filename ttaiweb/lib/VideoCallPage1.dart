// import 'dart:async';
// import 'dart:io';
// import 'dart:typed_data';
//
// // import 'package:agora_rtc_engine/agora_rtc_engine.dart';
// import 'package:agora_rtc_engine/agora_rtc_engine.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/rendering.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:logger/logger.dart';
// import 'package:permission_handler/permission_handler.dart';
//
// import 'AgoraCommon.dart';
// import 'AgoraUntils.dart';
// import 'AppLocalizations.dart';
// import 'AudioPlayerUtil.dart';
// import 'ConversationMessage.dart';
// import 'ConversationNotifier.dart';
// import 'LanguageManager.dart';
// import 'LanguageSelectionScreen.dart';
// import 'MessageContentLeft.dart';
// import 'MessageContentRight.dart';
// import 'XunFeiMachineTranslation.dart';
// import 'XunFeiRTASR.dart';
// import 'XunFeiTTS.dart';
//
//
// class VideoCallPage1 extends ConsumerStatefulWidget {
//   const VideoCallPage({super.key});
//
//   @override
//   _VideoCallPageState createState() => _VideoCallPageState();
// }
//
// class _VideoCallPageState extends ConsumerState<VideoCallPage>
//     with WidgetsBindingObserver{
//   final _scaffoldKey = GlobalKey<ScaffoldState>();
//   late RtcEngine _engine;
//   int? _remoteUid;
//   bool _localUserJoined = false;
//   final XunFeiRTASR _localRTASR = XunFeiRTASR();
//   final XunFeiRTASR _remoteRTASR = XunFeiRTASR();
//   final XunFeiTTS tts = XunFeiTTS();
//   final AudioPlayerUtil audioPlayerUtil = AudioPlayerUtil();
//   final ScrollController _scrollController = ScrollController();
//   //是否在录音状态
//   bool isLeftRecording = false;
//   bool isRightRecording = false;
//   final logger = Logger();
//   ConversationMessage? curFarMessage;
//   ConversationMessage? curNearMessage;
//   bool _isShareButtonsVisible = false;
//
//   bool isFrontCamera = true; // 默认使用前置摄像头
//   bool isMicMuted = false;  //控制麦克风是否静音
//   bool isVideoMuted = false; //控制视频流的开启与关闭
//   bool isSpeakerEnabled = true; //控制扬声器的开启与关闭
//
//   late final RtcEngineEventHandler _rtcEngineEventHandler;
//   late final AudioFrameObserver _audioFrameObserver;
//
//
//   @override
//   void initState() {
//     super.initState();
//     setState(() {
//       isLeftRecording = false;
//       isRightRecording = false;
//     });
//     ref.read(languageProvider.notifier).loadLanguages('languages');
//
//     WidgetsBinding.instance.addObserver(this);
//     // 在构建完成后进行状态更新
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       initAgora();
//     });
//   }
//
//   Future<void> initAgora() async {
//     print("emmmmmm initAgora");
//     // await _requestPermissions();
//     await _initializeAgoraVideoSDK();
//     await _setupRtcEngineEventHandler();
//     await _startAudioFrameRecord();
//     await _joinChannel();
//   }
//
//   // Requests microphone and camera permissions
//   Future<void> _requestPermissions() async {
//     await [Permission.microphone].request();
//   }
//
//
//   // Set up the Agora RTC engine instance
//   Future<void> _initializeAgoraVideoSDK() async {
//     _engine = createAgoraRtcEngine();
//     await _engine.initialize(RtcEngineContext(
//       appId: agoraAppId,
//       channelProfile: ChannelProfileType.channelProfileCommunication,
//       audioScenario: AudioScenarioType.audioScenarioDefault,
//     ));
//     // 设置音频参数
//     await _engine.setAudioProfile(
//       profile: AudioProfileType.audioProfileDefault,
//       scenario: AudioScenarioType.audioScenarioDefault, // 或适合您场景的配置
//     );
//
//
//   }
//
//   // Register an event handler for Agora RTC
//   Future<void> _setupRtcEngineEventHandler() async {
//     _rtcEngineEventHandler = RtcEngineEventHandler(
//       onJoinChannelSuccess: (RtcConnection connection, int elapsed) async {
//         print("emmmmmm Local user ${connection.localUid} joined");
//         await _localRTASR.startChannel();
//         setState(() => _localUserJoined = true);
//       },
//       onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) async {
//         print("emmmmmm Remote user $remoteUid joined");
//         await _remoteRTASR.startChannel();
//         setState(() {
//           _remoteUid = remoteUid;
//           _isShareButtonsVisible = false;
//         });
//       },
//       onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) async {
//         print("emmmmmm Remote user $remoteUid left");
//         await _remoteRTASR.stopWriteData();
//         setState(() => _remoteUid = null);
//       },
//       onUserMuteAudio: (RtcConnection connection, int remoteUid, bool muted) {
//         print("emmmmmm User $remoteUid has muted audio: $muted");
//       },
//       // 处理加入频道失败的错误
//       onError: (ErrorCodeType err, String errorMessage) {
//         // 记录加入房间失败的错误信息
//         print("emmmmmm Error: $errorMessage (ErrorCodeType: $err)");
//       },
//     );
//
//     _engine.registerEventHandler(_rtcEngineEventHandler);
//     await _engine.enableVideo();
//     await _engine.startPreview();
//
//   }
//
//
//   Future<void> _startAudioFrameRecord() async{
//     final leftLanguage = ref.read(languageSelectionProvider("VedioCall").notifier).getLeftSelectedLanguage();
//     final rightLanguage = ref.read(languageSelectionProvider("VedioCall").notifier).getRightSelectedLanguage();
//     _audioFrameObserver =  AudioFrameObserver(
//       onRecordAudioFrame: (String channelId, AudioFrame frame) async {
//         if(!_isShareButtonsVisible) {
//           final stereoPcm = frame.buffer!;
//           // if(!isAllZero(stereoPcm)){
//           processLocalAudio(
//             stereoPcm,
//             leftLanguage['code'], // 使用左侧选择的语言识别
//           );
//           // }
//         }
//       },
//       onPlaybackAudioFrame: (String channelId, AudioFrame frame) async {
//         if(!_isShareButtonsVisible){
//           final stereoPcm = frame.buffer!;
//           // if(!isAllZero(stereoPcm)) {
//           processRemoteAudio(
//             stereoPcm,
//             rightLanguage['code'], // 使用左侧选择的语言识别
//           );
//           // }
//         }
//       },
//     );
//
//     _engine.getMediaEngine().registerAudioFrameObserver(_audioFrameObserver);
//
//     await _engine.setPlaybackAudioFrameParameters(
//         sampleRate: 16000,
//         channel: 1,
//         mode: RawAudioFrameOpModeType.rawAudioFrameOpModeReadOnly,
//         samplesPerCall: 1280);
//     await _engine.setRecordingAudioFrameParameters(
//         sampleRate: 16000,
//         channel: 1,
//         mode: RawAudioFrameOpModeType.rawAudioFrameOpModeReadOnly,
//         samplesPerCall: 1280);
//   }
//
//   Future<void> _stopAudioFrameRecord() async{
//     _engine.getMediaEngine().unregisterAudioFrameObserver(_audioFrameObserver);
//   }
//
//   // 处理本地麦克风音频
//   Future<void> processLocalAudio(Uint8List pcmData, String lang) async {
//     // print("emmmmmm processLocalAudio:$lang");
//     if (_localRTASR.isFirst) {
//       ConversationMessage message = ConversationMessage(
//         originalText: "",
//         translatedText: "",
//         ttsFilePath: "",
//         isPlaying: false,
//         isTalking: false,
//         isLeft: false,
//       );
//       ref.read(conversationProviderTranslate.notifier).addMessage(message);
//       curNearMessage = message;
//       _localRTASR.onResult = (partialResult)
//       {
//         logger.d("emmmmmm 中间结果: $partialResult");
//         if(mounted){
//           curNearMessage?.originalText = partialResult;
//           ref.read(conversationProviderTranslate.notifier).updateMessage(curNearMessage!);
//           scrollToEnd();
//         }
//       };
//       _localRTASR.onEndResult = (finalResult)
//       {
//         if(mounted){
//           logger.d("emmmmmm 最终结果: $finalResult");
//           //处理翻译结果
//           _handleFinalResult(finalResult, curNearMessage!, false, ref);
//           ConversationMessage newMessage = ConversationMessage(
//             originalText: "",
//             translatedText: "",
//             ttsFilePath: "",
//             isPlaying: false,
//             isTalking: false,
//             isLeft: false,
//           );
//           ref.read(conversationProviderTranslate.notifier).addMessage(newMessage);
//           curNearMessage = newMessage;
//           scrollToEnd();
//         }
//       };
//     }
//     // writer.write(pcmData);
//     _localRTASR.writeAudioData(lang, 0 , pcmData);
//   }
//
//   // 处理远端用户音频
//   void processRemoteAudio(Uint8List pcmData, String lang) {
//     // print("emmmmmm processRemoteAudio$lang");
//     if (_remoteRTASR.isFirst) {
//       ConversationMessage message = ConversationMessage(
//         originalText: "",
//         translatedText: "",
//         ttsFilePath: "",
//         isPlaying: false,
//         isTalking: false,
//         isLeft: true,
//       );
//       ref.read(conversationProviderTranslate.notifier).addMessage(message);
//       curFarMessage = message;
//       _remoteRTASR.onResult = (partialResult)
//       {
//         if(mounted){
//           logger.d("emmmmmm 远端中间结果: $partialResult");
//           curFarMessage?.originalText = partialResult;
//           ref.read(conversationProviderTranslate.notifier).updateMessage(curFarMessage!);
//           scrollToEnd();
//         }
//       };
//       _remoteRTASR.onEndResult = (finalResult)
//       {
//         if(mounted){
//           logger.d("emmmmmm 远端最终结果: $finalResult");
//           //处理翻译结果
//           _handleFinalResult(finalResult, curFarMessage!, true, ref);
//           ConversationMessage newMessage = ConversationMessage(
//             originalText: "",
//             translatedText: "",
//             ttsFilePath: "",
//             isPlaying: false,
//             isTalking: false,
//             isLeft: true,
//           );
//           ref.read(conversationProviderTranslate.notifier).addMessage(newMessage);
//           curFarMessage = newMessage;
//           scrollToEnd();
//         }
//       };
//     }
//     // writer.write(pcmData);
//     _remoteRTASR.writeAudioData(lang, 0 , pcmData);
//   }
//
//   bool isAllZero(Uint8List? buffer) {
//     if (buffer == null) return false;
//     for (int i = 0; i < buffer.length; i++) {
//       if (buffer[i] != 0) {
//         return false;
//       }
//     }
//     return true;
//   }
//
//   // Join a channel
//   Future<void> _joinChannel() async {
//     // 获取 UID 和 Channel Name
//     // final userState = ref.read(userProvider);
//     // int uid = int.parse(userState.userData?["userId"] ?? '0');
//     // print("emmmmmm uid:$uid");
//     // agoraChannel = 'test_channel';//${uid}_Channel';
//     // 调用 API 获取 Token
//     try{
//       print("agoraChannelId:$agoraChannelId");
//       //agoraToken = '007eJxTYNB1MXUXF/jkvrYi1q7vZy2zdg9Pf73vk1mc8u1ZlndurFBgMDBJNjJLtEhLNDcyMDFLtExKMUw0SzFMM04ytExMszQ7nfQ9vSGQkSF1qx8LIwMjAwsQg/hMYJIZTLKASR6GktTikvjkjMS8vNQcBgYA0R0jrg==';
//       agoraToken = (await generateAgoraToken("rtc", agoraChannelId, "publisher", 0, 3600))!;
//       print("从云端获取token:$agoraToken");
//       await _engine.joinChannel(
//         token: agoraToken,
//         channelId: agoraChannelId,
//         options: const ChannelMediaOptions(
//           // autoSubscribeVideo: true,
//           // autoSubscribeAudio: true,
//           // publishCameraTrack: true,
//           // publishMicrophoneTrack: true,
//           channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
//           clientRoleType: ClientRoleType.clientRoleBroadcaster,
//         ),
//         uid: 0,
//       );
//     }catch(e){
//       print("Failed to get Agora Token.");
//     }
//   }
//
//   //切换摄像头（前后摄像头）
//   Future<void> toggleCamera() async{
//     setState(() {
//       isFrontCamera = !isFrontCamera;
//     });
//     await _engine.switchCamera(); // 切换摄像头
//   }
//
//   //控制麦克风开启与关闭
//   Future<void> toggleMic() async{
//     setState(() {
//       isMicMuted = !isMicMuted;
//     });
//     await _engine.enableLocalAudio(!isMicMuted); // 如果麦克风未静音，则启用音频捕获
//     await _engine.muteLocalAudioStream(isMicMuted); // // 如果麦克风静音，则停止发布音频流
//   }
//
//   //控制视频流的开启与关闭
//   Future<void> toggleCameraStream() async {
//     print("控制视频流的开启与关闭 $isVideoMuted");
//
//     setState(() {
//       isVideoMuted = !isVideoMuted;
//     });
//
//     if (isVideoMuted) {
//       // 如果视频被禁用，关闭本地视频捕获并停止发布视频流
//       await _engine.enableLocalVideo(false); // 禁用本地视频捕获
//       await _engine.muteLocalVideoStream(true); // 停止发布视频流
//     } else {
//       // 否则，启用本地视频捕获并恢复发布视频流
//       await _engine.enableLocalVideo(true); // 启用本地视频捕获
//       await _engine.muteLocalVideoStream(false); // 恢复发布视频流
//     }
//   }
//
//
//   //退出当前频道
//   Future<void> exitChannel() async{
//     ref.read(conversationProviderTranslate.notifier).clearMessages();
//     Navigator.pop(context); // 返回到上一个页面
//   }
//
//   //控制扬声器的开启与关闭
//   Future<void> toggleSpeaker() async{
//     setState(() {
//       isSpeakerEnabled = !isSpeakerEnabled;
//     });
//     await _engine.setEnableSpeakerphone(isSpeakerEnabled); // 切换扬声器的开启与关闭
//   }
//
//
//
//
//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     switch (state) {
//       case AppLifecycleState.inactive:
//         break;
//       case AppLifecycleState.resumed: //Switch from the background to the foreground, and the interface is visible
//         break;
//       case AppLifecycleState.paused: // Interface invisible, background
//       // 当应用进入后台时停止播放
//         audioPlayerUtil.stop();
//         break;
//       case AppLifecycleState.detached:
//         break;
//       case AppLifecycleState.hidden:
//         break;
//     }
//   }
//
//   // Displays remote video view
//   Widget _localVideo() {
//     return AgoraVideoView(
//       controller: VideoViewController(
//         rtcEngine: _engine,
//         canvas: const VideoCanvas(
//           uid: 0,
//           renderMode: RenderModeType.renderModeHidden,
//         ),
//       ),
//     );
//   }
//
//   // Display remote user's video
//   Widget _remoteVideo() {
//     if (_remoteUid != null) {
//       // print("emmmmmm _remoteUid:$_remoteUid");
//       return AgoraVideoView(
//         controller: VideoViewController.remote(
//           rtcEngine: _engine,
//           canvas: VideoCanvas(uid: _remoteUid),
//           connection: RtcConnection(channelId: agoraChannelId),
//         ),
//       );
//     } else {
//       return const Text(
//         'Please wait for remote user to join',
//         textAlign: TextAlign.center,
//       );
//     }
//   }
//
//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     audioPlayerUtil.stop();
//     _cleanupAgoraEngine();
//     super.dispose();
//   }
//
//   // Leaves the channel and releases resources
//   Future<void> _cleanupAgoraEngine() async {
//     _engine.unregisterEventHandler(_rtcEngineEventHandler);
//     _stopAudioFrameRecord();
//     await _engine.leaveChannel();
//     await _engine.release();
//     _localRTASR.stopWriteData();
//     _remoteRTASR.stopWriteData();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     ref.watch(conversationProviderTranslate);
//     return Scaffold(
//       backgroundColor: Colors.black54,
//       key: _scaffoldKey,
//       body: WillPopScope(
//         onWillPop: () async {
//           // _trtcCloud.exitRoom();
//           return true;
//         },
//         child: Column(
//           children: [
//
//             // 顶部栏
//             Expanded(
//               flex: 1,
//               child: _buildTopBar(context),
//             ),
//
//             // 视频区域 + 浮层内容
//             Expanded(
//               flex: 9,
//               child: Stack(
//                 children: [
//                   // 远程视频全屏显示（_buildTopBar 下面）
//                   Positioned.fill(
//                     child: _remoteVideo(),
//                   ),
//
//                   // 本地视频浮动在右上角
//                   Positioned(
//                     top: 0,
//                     right: 20,
//                     width: 150,
//                     height: 200,
//                     child: _localUserJoined && !isVideoMuted
//                         ? _localVideo()
//                         : const Center(
//                         child: CircleAvatar(
//                           radius: 40,
//                           backgroundColor: Colors.black,
//                           child: Icon(Icons.person, size: 40, color: Colors.white),
//                         )
//                     ),
//                   ),
//
//                   // 中间内容 + 底部栏合并为一个Align + Column
//                   Align(
//                     alignment: Alignment.bottomCenter,
//                     child: Column(
//                       mainAxisSize: MainAxisSize.min, // 内容多高就多高，避免撑满整个Stack
//                       children: [
//                         // 中间分享按钮或对话列表
//                         _isShareButtonsVisible
//                             ? _buildShareButtons()
//                             : _buildConversationList(),
//
//                         // 底部栏
//                         SizedBox(
//                           child: _buildBottomBar(),
//                         ),
//                       ],
//                     ),
//                   ),
//
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//
//   Widget _buildTopBar(BuildContext context) {
//     final selectionState =
//     ref.watch(languageSelectionProvider("VedioCall"));
//     final selectionNotifier =
//     ref.read(languageSelectionProvider("VedioCall").notifier);
//     return Consumer(
//       builder: (context, watch, _) {
//         final languageState = ref.watch(languageProvider);
//         final localization = AppLocalizations.of(context)!;
//         print("languageState$languageState");
//         if (languageState is AsyncLoading) {
//           return Center(child: CircularProgressIndicator());
//         } else if (languageState is AsyncError) {
//           return Center(child: Text(localization.translate('加载语言失败')));
//         } else if (languageState is AsyncData) {
//           final leftLanguage = selectionNotifier.getLeftSelectedLanguage();
//           final rightLanguage = selectionNotifier.getRightSelectedLanguage();
//
//           print("leftLanguage: $leftLanguage");
//
//           return Padding(
//             padding: const EdgeInsets.only(top: 12.0, bottom: 8),
//             // 移除左右的 padding
//             child: Row(
//               children: [
//                 // 返回按钮固定在左侧
//                 IconButton(
//                   icon: const Icon(Icons.arrow_back, color: Colors.white),
//                   onPressed: () {
//                     ref.read(conversationProviderTranslate.notifier).clearMessages();
//                     Navigator.pop(context);
//                   },
//                 ),
//                 // 其他内容居中
//                 Expanded(
//                   child: Center(
//                     // 将其他内容居中
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       mainAxisAlignment: MainAxisAlignment.center, // 居中对齐
//                       children: [
//                         _buildLanguageButtonWithIcon(
//                           text: leftLanguage.isEmpty
//                               ? "中文"
//                               : leftLanguage['displayName'] ?? "中文",
//                           onPressed: () => _onLanguageButtonPressed(
//                               context, selectionState.leftLanguageIndex,
//                                   (index) {
//                                 ref
//                                     .read(languageSelectionProvider("VedioCall")
//                                     .notifier)
//                                     .selectLeftLanguage(index);
//                               }),
//                           isEnabled: !(isLeftRecording || isRightRecording),
//                         ),
//                         const SizedBox(width: 10),
//                         _buildLanguageSwapButton(
//                           isEnabled: !(isLeftRecording || isRightRecording),
//                         ),
//                         const SizedBox(width: 10),
//                         _buildLanguageButtonWithIcon(
//                           text: rightLanguage.isEmpty
//                               ? "英文"
//                               : rightLanguage['displayName'] ?? "English",
//                           onPressed: () => _onLanguageButtonPressed(
//                               context, selectionState.rightLanguageIndex,
//                                   (index) {
//                                 final not = ref
//                                     .read(languageSelectionProvider(
//                                     "VedioCall")
//                                     .notifier);
//                                 not.selectRightLanguage(index);
//                               }),
//                           isEnabled: !(isLeftRecording || isRightRecording),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           );
//         }
//
//         return SizedBox.shrink();
//       },
//     );
//   }
//
//   Widget _buildLanguageButtonWithIcon({
//     required String text,
//     required VoidCallback onPressed,
//     bool isEnabled = true, // 录音时禁用
//   }) {
//     return Opacity(
//       opacity: isEnabled ? 1.0 : 0.5, // 禁用时降低透明度
//       child: TextButton(
//         onPressed: isEnabled ? onPressed : null, // 禁用时 `onPressed` 设为 `null`
//         style: TextButton.styleFrom(
//           foregroundColor: Colors.white,
//           padding: const EdgeInsets.symmetric(horizontal: 8),
//           textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//         ),
//         child: Center(
//           child: Row(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Container(
//                 constraints: BoxConstraints(maxWidth: 80),
//                 child: Text(
//                   text,
//                   softWrap: true,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//               ),
//               const Icon(Icons.arrow_drop_down, size: 20, color: Colors.white),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildLanguageSwapButton({bool isEnabled = true}) {
//     return Opacity(
//       opacity: isEnabled ? 1.0 : 0.5, // 禁用时降低透明度
//       child: GestureDetector(
//         onTap: isEnabled
//             ? () {
//           ref
//               .read(
//               languageSelectionProvider("VedioCall").notifier)
//               .swapLanguages();
//         }
//             : null, // 禁用时不执行点击事件
//         child: Container(
//           decoration: BoxDecoration(
//             color: Colors.white,
//             shape: BoxShape.rectangle,
//             borderRadius: BorderRadius.circular(25),
//           ),
//           width: 60,
//           height: 30,
//           padding: const EdgeInsets.all(1),
//           child: const Icon(Icons.swap_horiz, color: Colors.blue),
//         ),
//       ),
//     );
//   }
//
//   void _onLanguageButtonPressed(
//       BuildContext context, int index, Function(int) callback) {
//     // 左右应不能选择同一种语言
//     final selectionNotifier =
//     ref.read(languageSelectionProvider("VedioCall").notifier);
//     final leftLanguage = selectionNotifier.getLeftSelectedLanguage();
//     final rightLanguage = selectionNotifier.getRightSelectedLanguage();
//
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => LanguageSelectionScreen(
//           pageKey: "VedioCall",
//           currentIndex: index,
//           // 左右应不能选择同一种语言
//           callback: (selectedIndex) {
//             // 获取选择的语言
//             final selectedLanguage =
//             selectionNotifier.state.getLanguage(selectedIndex);
//
//             // 检查是否与另一侧的语言相同
//             if ((index == selectionNotifier.state.leftLanguageIndex &&
//                 selectedLanguage['code'] == rightLanguage['code']) ||
//                 (index == selectionNotifier.state.rightLanguageIndex &&
//                     selectedLanguage['code'] == leftLanguage['code'])) {
//               // 提示用户选择不同的语言
//               ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//                 content:
//                 Text(AppLocalizations.of(context)!.translate("请选择不同的语言")),
//                 duration: Duration(seconds: 2),
//               ));
//             } else {
//               // 更新选择
//               callback(selectedIndex);
//             }
//           },
//         ),
//       ),
//     );
//   }
//
//   Widget _buildConversationList() {
//     return Expanded(
//       child: Consumer(
//         builder: (context, ref, _) {
//           final conversation = ref.watch(conversationProviderTranslate);
//           //自动滚动到列表的最后
//           WidgetsBinding.instance.addPostFrameCallback((_) {
//             scrollToEnd();
//           });
//           final playingFilePath =
//               ref.watch(conversationProviderTranslate.notifier).playingFilePath;
//           return ListView.builder(
//             controller: _scrollController,
//             padding: const EdgeInsets.symmetric(horizontal: 15),
//             itemCount: conversation.length,
//             itemBuilder: (context, index) {
//               final message = conversation[index];
//               return Padding(
//                 padding: const EdgeInsets.symmetric(vertical: 8.0),
//                 child: message.isLeft
//                     ? MessageContentLeft(
//                     originalText: message.originalText,
//                     translatedText: message.translatedText,
//                     ttsFilePath: message.ttsFilePath,
//                     isPlaying: message.isPlaying,
//                     isTalking: message.isTalking,
//                     playingFilePath: playingFilePath,
//                     onPlay: () => _onPlay(message, ref),
//                     onStop: () => _onStop(message, ref),
//                     originalTextColor: null,
//                     isAutoPlaying: message.isAutoPlaying)
//                     : MessageContentRight(
//                     originalText: message.originalText,
//                     translatedText: message.translatedText,
//                     ttsFilePath: message.ttsFilePath,
//                     isPlaying: message.isPlaying,
//                     isTalking: message.isTalking,
//                     playingFilePath: playingFilePath,
//                     onPlay: () => _onPlay(message, ref),
//                     onStop: () => _onStop(message, ref),
//                     isAutoPlaying: message.isAutoPlaying),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
//
//   Widget _buildBottomBar() {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 60.0,horizontal: 10.0),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.end,
//         children: [
//           // 顶部两按钮
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//             children: [
//               _buildBottomImageButton(
//                 iconUrl: 'assets/images/ttai/ic_veidocall_camera_btn.png',
//                 onPressed: toggleCamera,
//               ),
//               _buildBottomImageButton(
//                 iconUrl: '',
//                 onPressed: () {
//
//                 },
//               ),
//               _buildBottomImageButton(
//                 iconUrl: 'assets/images/ttai/ic_veidocall_vedio_btn.png',
//                 onPressed: toggleCameraStream,
//               ),
//             ],
//           ),
//           SizedBox(height: 20), // 上下间距
//           // 底部三按钮
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//             crossAxisAlignment: CrossAxisAlignment.center, // 确保对齐方式一致
//
//             children: [
//               _buildBottomImageButton(
//                 iconUrl: isMicMuted ? 'assets/images/ttai/ic_veidocall_mic_off_btn.png' : 'assets/images/ttai/ic_veidocall_mic_btn.png' ,
//                 onPressed: toggleMic,
//               ),
//               _buildBottomImageButton(
//                 iconUrl: 'assets/images/ttai/ic_veidocall_exit_btn.png',
//                 onPressed: exitChannel,
//               ),
//               _buildBottomImageButton(
//                 iconUrl: isSpeakerEnabled ? 'assets/images/ttai/ic_veidocall_volume_btn.png' : 'assets/images/ttai/ic_veidocall_volume_off_btn.png',
//                 onPressed: toggleSpeaker,
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildBottomImageButton({
//     required String iconUrl,
//     required VoidCallback onPressed,
//   }) {
//     return GestureDetector(
//       onTap: onPressed,
//       child: Container(
//         width: 60,  // 设置按钮的宽度
//         height: 60, // 设置按钮的高度
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(30), // 设置圆角效果
//           color: iconUrl.isEmpty ? Colors.transparent : Colors.grey, // 如果是空按钮，设置为透明
//         ),
//         child: iconUrl.isNotEmpty
//             ? Image.asset(
//           iconUrl,
//           width: 60,  // 设置图像的宽度
//           height: 60, // 设置图像的高度
//           fit: BoxFit.contain,
//         )
//             : null,  // 空按钮没有图片
//       ),
//     );
//   }
//
//   Widget _buildShareButtons() {
//     if (!_isShareButtonsVisible) {
//       return _buildConversationList(); // 返回空的组件，隐藏按钮
//     }
//
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 10.0),
//       child: Column(
//         children: [
//           _buildShareButton(
//             iconUrl: 'assets/images/ttai/ic_veidocall_copylink_icon.png',
//             label: "复制链接",
//             onPressed: () {
//               // 复制链接操作
//             },
//           ),
//           _buildShareButton(
//             iconUrl: 'assets/images/ttai/ic_veidocall_wechat_icon.png',
//             label: "通过微信分享",
//             onPressed: () {
//               // 微信分享操作
//             },
//           ),
//           _buildShareButton(
//             iconUrl: 'assets/images/ttai/ic_veidocall_link_icon.png',
//             label: "通过Line分享",
//             onPressed: () {
//               // Line分享操作
//             },
//           ),
//           _buildShareButton(
//             iconUrl: 'assets/images/ttai/ic_veidocall_in_icon.png',
//             label: "通过LinkedIn分享",
//             onPressed: () {
//               // LinkedIn分享操作
//             },
//           ),
//         ],
//       ),
//     );
//   }
//
//
//   Widget _buildShareButton({
//     required String iconUrl,
//     required String label,
//     required VoidCallback onPressed,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 15.0),
//       child: ElevatedButton(
//         onPressed: onPressed,
//         style: ElevatedButton.styleFrom(
//           padding: EdgeInsets.symmetric(vertical: 5.0, horizontal: 15.0),
//           backgroundColor: Colors.white70,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(30.0),
//           ),
//           side: BorderSide(color: Colors.grey.withOpacity(0.5)),
//         ),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Image.asset(
//               iconUrl,
//               width: 25,  // 设置图像的宽度
//               height: 25, // 设置图像的高度
//             ),
//             SizedBox(width: 10),
//             Text(
//               label,
//               style: TextStyle(
//                 color: Colors.black,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   void _onPlay(ConversationMessage message, WidgetRef ref) {
//     // // 停止录音并显示已识别的内容
//     // if (isLeftRecording || isRightRecording) {
//     //   _stopASR();
//     //   _onStop(message, ref);
//     // }
//     //
//     // // 当最新消息正在自动播放时，如果点击上面的对话内容的按钮，停止播放和动画
//     // if (curFarMessage != null) {
//     //   curFarMessage!.isAutoPlaying = false;
//     //   curFarMessage!.isPlaying = false;
//     //   ref
//     //       .read(conversationProviderTranslate.notifier)
//     //       .updateMessage(curFarMessage!);
//     // }
//     //
//     // final notifier = ref.read(conversationProviderTranslate.notifier);
//     //
//     // // 如果有其他音频在播放，先停止
//     // if (notifier.playingFilePath != null) {
//     //   audioPlayerUtil.stop();
//     // }
//     // curFarMessage?.isPlaying = false;
//     // curFarMessage?.isAutoPlaying = false;
//     // notifier.updateMessage(curFarMessage!);
//     // curFarMessage = message;
//     // // 设置新的播放状态
//     // notifier.setPlayingFilePath(message.ttsFilePath);
//     // message.isPlaying = true;
//     // message.isAutoPlaying = true; // Start animation
//     // notifier.updateMessage(message);
//     //
//     // audioPlayerUtil.playPCMFromFile(message.ttsFilePath, () {
//     //   // 播放完毕后清除状态
//     //   message.isPlaying = false;
//     //   message.isAutoPlaying = false;
//     //   notifier.setPlayingFilePath(null);
//     //   notifier.updateMessage(message);
//     // });
//   }
//
//   void _onStop(ConversationMessage message, WidgetRef ref) {
//     // final notifier = ref.read(conversationProviderTranslate.notifier);
//     //
//     // audioPlayerUtil.stop();
//     // message.isPlaying = false;
//     // message.isAutoPlaying = false;
//     // notifier.setPlayingFilePath(null);
//     // notifier.updateMessage(message);
//   }
//
//
//   void _handleFinalResult(String finalResult, ConversationMessage message,
//       bool isLeft, WidgetRef ref) {
//     if (finalResult.isEmpty) {
//       ref.read(conversationProviderTranslate.notifier).removeMessage(message);
//     } else {
//       message.originalText = finalResult;
//       ref.read(conversationProviderTranslate.notifier).updateMessage(message);
//       XunFeiMachineTranslation.sendMessage(
//         finalResult,
//         isLeft
//             ? ref
//             .read(languageSelectionProvider("VedioCall").notifier)
//             .getRightSelectedLanguage()['code']
//             : ref
//             .read(languageSelectionProvider("VedioCall").notifier)
//             .getLeftSelectedLanguage()['code'],
//         isLeft
//             ? ref
//             .read(languageSelectionProvider("VedioCall").notifier)
//             .getLeftSelectedLanguage()['code']
//             : ref
//             .read(languageSelectionProvider("VedioCall").notifier)
//             .getRightSelectedLanguage()['code'],
//             (result) {
//           print("reslut:$result,isLeft$isLeft");
//           message.translatedText = result;
//           ref
//               .read(conversationProviderTranslate.notifier)
//               .updateMessage(message);
//           // tts
//           // tts.startTTS(
//           //     result,
//           //     isLeft
//           //         ? ref
//           //         .read(languageSelectionProvider("VedioCall")
//           //         .notifier)
//           //         .getRightSelectedLanguage()['voice']
//           //         : ref
//           //         .read(languageSelectionProvider("VedioCall")
//           //         .notifier)
//           //         .getLeftSelectedLanguage()['voice'], (filepath) {
//           //   message.ttsFilePath = filepath;
//           //   ref
//           //       .read(conversationProviderTranslate.notifier)
//           //       .updateMessage(message);
//           //
//           //   // 检查是否有正在播放的消息
//           //   final notifier = ref.read(conversationProviderTranslate.notifier);
//           //   if (notifier.playingFilePath != null) {
//           //     // 如果有正在播放的消息，等待它播放完成后再播放新消息
//           //     message.isPlaying = false;
//           //     message.isAutoPlaying = false;
//           //     ref
//           //         .read(conversationProviderTranslate.notifier)
//           //         .updateMessage(message);
//           //
//           //     // 监听当前播放的消息状态
//           //     final currentPlayingMessage = ref
//           //         .read(conversationProviderTranslate)
//           //         .firstWhere(
//           //             (msg) => msg.ttsFilePath == notifier.playingFilePath);
//           //
//           //     // 创建一个定时器来检查播放状态
//           //     Timer.periodic(Duration(milliseconds: 100), (timer) {
//           //       if (!currentPlayingMessage.isPlaying) {
//           //         timer.cancel();
//           //         // 当前消息播放完成，开始播放新消息
//           //         message.isPlaying = true;
//           //         message.isAutoPlaying = true;
//           //         ref
//           //             .read(conversationProviderTranslate.notifier)
//           //             .updateMessage(message);
//           //         curMessage = message;
//           //         audioPlayerUtil.playPCMFromFile(filepath, () {
//           //           message.isPlaying = false;
//           //           message.isAutoPlaying = false;
//           //           ref
//           //               .read(conversationProviderTranslate.notifier)
//           //               .updateMessage(message);
//           //         });
//           //       }
//           //     });
//           //   } else {
//           //     // 如果没有正在播放的消息，直接播放新消息
//           //     message.isPlaying = true;
//           //     message.isAutoPlaying = true;
//           //     ref
//           //         .read(conversationProviderTranslate.notifier)
//           //         .updateMessage(message);
//           //     curMessage = message;
//           //     audioPlayerUtil.playPCMFromFile(filepath, () {
//           //       message.isPlaying = false;
//           //       message.isAutoPlaying = false;
//           //       ref
//           //           .read(conversationProviderTranslate.notifier)
//           //           .updateMessage(message);
//           //     });
//           //   }
//           // }, () {}, false);
//         },
//             (error) {
//           print("翻译失败: $error");
//         },
//       );
//     }
//     scrollToEnd();
//   }
//
//
//   void scrollToEnd() {
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (_scrollController.hasClients) {
//         _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
//       }
//     });
//   }
// }