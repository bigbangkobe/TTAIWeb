import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:universal_html/html.dart' as html;
import 'package:zego_express_engine/zego_express_engine.dart';

import 'AppLocalizations.dart';
import 'ConversationMessage.dart';
import 'ConversationNotifier.dart';
import 'LanguageManager.dart';
import 'LanguageSelectionScreen.dart';
import 'MessageContentLeft.dart';
import 'MessageContentRight.dart';
import 'XunFeiMachineTranslation.dart';
import 'XunFeiRTASR.dart';
import 'XunFeiTTS.dart';
import 'ZegoUntils.dart';

class VideoCallPage extends ConsumerStatefulWidget {
  const VideoCallPage({super.key});

  @override
  _VideoCallPageState createState() => _VideoCallPageState();
}

class _VideoCallPageState extends ConsumerState<VideoCallPage>
    with WidgetsBindingObserver{
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  final XunFeiRTASR _localRTASR = XunFeiRTASR();
  final XunFeiRTASR _remoteRTASR = XunFeiRTASR();
  final XunFeiTTS tts = XunFeiTTS();
  // final AudioPlayerUtil audioPlayerUtil = AudioPlayerUtil();
  final ScrollController _scrollController = ScrollController();
  //是否在录音状态
  bool isLeftRecording = false;
  bool isRightRecording = false;
  final logger = Logger();
  ConversationMessage? curFarMessage;
  ConversationMessage? curNearMessage;

  bool isFrontCamera = true; // 默认使用前置摄像头
  bool isMicMuted = false;  //控制麦克风是否静音
  bool isVideoMuted = false; //控制视频流的开启与关闭
  bool isSpeakerEnabled = true; //控制扬声器的开启与关闭

  int _previewViewID = -1;
  int _playViewID = -1;
  Widget? _previewViewWidget;
  Widget? _playViewWidget;
  ZegoMediaPlayer? mediaPlayer;

  bool _isEngineActive = false;
  ZegoRoomState _roomState = ZegoRoomState.Disconnected;
  ZegoPublisherState _publisherState = ZegoPublisherState.NoPublish;
  ZegoPlayerState _playerState = ZegoPlayerState.NoPlay;
  late ZegoUser _localZegoUser;
  late ZegoUser _remoteZegoUser;
  // ZegoMediaPlayer? _mediaPlayer;


  @override
  void initState() {
    super.initState();
    setState(() {
      isLeftRecording = false;
      isRightRecording = false;
    });
    ref.read(languageProvider.notifier).loadLanguages('languages');

    // 添加监听页面关闭或刷新事件
    if (kIsWeb) {
      html.window.onBeforeUnload.listen((event) async {
        // 退出房间并清理资源
        await _cleanupEngine();
      });
    }

    WidgetsBinding.instance.addObserver(this);
    // 在构建完成后进行状态更新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initZego();
    });
  }

  Future<void> initZego() async {
    print("emmmmmm initSDK");
    await _requestPermissions();
    await _setupEventHandler();
    await _initializeSDK();
    await _startAudioFrameRecord();
    await loginRoom();
  }

  // Requests microphone and camera permissions
  Future<void> _requestPermissions() async {
    // await [Permission.microphone,Permission.camera].request();
    try {
      // 请求摄像头和麦克风的权限
      final mediaStream = await html.window.navigator.mediaDevices?.getUserMedia({
        'video': true, // 请求视频权限
        'audio': true, // 请求音频权限
      });

      // 成功获取权限，进行处理
      print('Camera and microphone access granted');
      // 你可以在这里对 mediaStream 进行进一步操作，例如显示视频流等
    } catch (e) {
      // 处理错误，例如用户拒绝权限
      print('Error requesting permission: $e');
    }
  }


  Future<void> _initializeSDK() async {
    print('🚀 _initializeSDK enablePlatformView:${ZegoConfig.instance.enablePlatformView}');
    ZegoEngineProfile profile = ZegoEngineProfile(
        ZegoConfig.instance.appID,
        ZegoConfig.instance.scenario,
        enablePlatformView: ZegoConfig.instance.enablePlatformView,
        appSign: kIsWeb ? null : ZegoConfig.instance.appSign);
    if (kIsWeb) {
      profile.appSign = null; // Don't use appsign on web
    }
    await ZegoExpressEngine.createEngineWithProfile(profile);

    // Notify View that engine state changed
    setState(() => _isEngineActive = true);

    print('🚀 Create ZegoExpressEngine');

  }

  // Register an event handler for Agora RTC
  Future<void> _setupEventHandler() async {

    //The following are commonly used room-related callbacks
    // Room status update callback
    ZegoExpressEngine.onRoomStateUpdate = (String roomID, ZegoRoomState state, int errorCode, Map<String, dynamic> extendedData) {
      // Implement event callbacks as needed
      print('🚩 🚪 Room state update, state: $state, errorCode: $errorCode, roomID: $roomID');
      setState(() => _roomState = state);
    };

    //User status update
    ZegoExpressEngine.onRoomUserUpdate = (String roomID, ZegoUpdateType updateType, List<ZegoUser> userList) {
      userList.forEach((user) {
        if(_localZegoUser.userID != user.userID){
          _remoteZegoUser = user;

        }else{
          _localZegoUser = user;
        }
        var userID = user.userID;
        var userName = user.userName;
        print('🚩 🚪 Room user update, roomID: $roomID, updateType: $updateType userID: $userID userName: $userName');
      });
      print('🚩 🚪 Room user update, roomID: $roomID, updateType: $updateType count: ${userList.length}');

    };

    //Stream status update
    ZegoExpressEngine.onRoomStreamUpdate = (String roomID, ZegoUpdateType updateType, List<ZegoStream> streamList, Map<String, dynamic> extendedData) {
      // Implement event callbacks as needed
      streamList.forEach((stream) {
        var streamID = stream.streamID;
        startPlayingStream(streamID);
        print('🚩 🚪 Room stream update, roomID: $roomID, updateType: $updateType streamID:$streamID');
      });
    };

    ZegoExpressEngine.onPlayerStateUpdate = (String streamID,
        ZegoPlayerState state,
        int errorCode,
        Map<String, dynamic> extendedData) {
      print('🚩 📥 Player state update, state: $state, errorCode: $errorCode, streamID: $streamID');
      setState(() => _playerState = state);
    };

    // Common stream publishing-related callbacks
    // Callback for stream publishing state updates
    ZegoExpressEngine.onPublisherStateUpdate = (String streamID, ZegoPublisherState state, int errorCode, Map<String, dynamic> extendedData) {
      // Implement the event callback as needed
      _publisherState = state;
    };
  }


  Future<void> _startAudioFrameRecord() async{
    final leftLanguage = ref.read(languageSelectionProvider("VedioCall").notifier).getLeftSelectedLanguage();
    final rightLanguage = ref.read(languageSelectionProvider("VedioCall").notifier).getRightSelectedLanguage();

    ZegoAudioFrameParam param = ZegoAudioFrameParam(
        ZegoAudioSampleRate.SampleRate16K,   // 44100Hz is a common sample rate
        ZegoAudioChannel.Mono
    );
    int observerBitMask = ZegoAudioDataCallbackBitMask.Mixed|ZegoAudioDataCallbackBitMask.Player;
    ZegoExpressEngine.instance.startAudioDataObserver(observerBitMask, param);
    ZegoExpressEngine.onMixedAudioData = ((data, length, param) {
      final noZegoLength = this.countValuesGreaterThanZero(data);
      print(
          '🚩 fffflutter onMixedAudioData, length:$noZegoLength/$length ${param.channel} ${param.sampleRate}');
      // 处理本地PCM音频数据...
      if(mounted){
        processLocalAudio(
          convertFloat32ToInt16(data),
          leftLanguage['code'], // 使用左侧选择的语言识别
        );
      }
    });
    ZegoExpressEngine.onPlayerAudioData = ((data, length, param, streamID) {
      // final noZegoLength = this.countValuesGreaterThanZero(data);
      // print(
      //     '🚩 fffflutter onPlayerAudioData, length:$noZegoLength/$length streamID:$streamID ${param.channel} ${param.sampleRate}');
      // 处理特定流的远端音频数据...
      if(mounted){
        processRemoteAudio(
          convertFloat32ToInt16(data),
          rightLanguage['code'], // 使用左侧选择的语言识别
        );
      }
    });
    ZegoExpressEngine.onPlaybackAudioData = ((data, length, param) {
      // final noZegoLength = this.countValuesGreaterThanZero(data);
      // print(
      //     '🚩 fffflutter onPlaybackAudioData, length:$noZegoLength/$length ${param.channel} ${param.sampleRate}');
    });
    ZegoExpressEngine.onCapturedAudioData = ((data, length, param) {
      // final noZegoLength = this.countValuesGreaterThanZero(data);
      // print(
      //     '🚩 fffflutter onCapturedAudioData, length:$noZegoLength/$length ${param.channel} ${param.sampleRate}');
    });
    // 设置本地音频数据回调
    // ZegoExpressEngine.onCapturedAudioData = (data, length, param) {
    //   // 处理本地PCM音频数据...
    //   if(mounted){
    //     processLocalAudio(
    //       data,
    //       leftLanguage['code'], // 使用左侧选择的语言识别
    //     );
    //   }
    // };
    //
    //
    // // 设置远端音频数据回调
    // ZegoExpressEngine.onPlayerAudioData = (data, length, param, streamID) {
    //   // 处理特定流的远端音频数据...
    //   if(mounted){
    //     processRemoteAudio(
    //       data,
    //       rightLanguage['code'], // 使用左侧选择的语言识别
    //     );
    //   }
    // };
    // ZegoExpressEngine.onCapturedAudioData = ((data, length, param) {
    //
    //   // 处理本地PCM音频数据...
    //   if(mounted){
    //     final noZegoLength = this.countValuesGreaterThanZero(data);
    //     print('🚩 emmmmmm onCapturedAudioData, length:$noZegoLength/$length ${param.channel} ${param.sampleRate}');
    //     processLocalAudio(
    //       data,
    //       leftLanguage['code'], // 使用左侧选择的语言识别
    //     );
    //   }
    // });
    // ZegoExpressEngine.onPlayerAudioData = ((data, length, param, streamID) {
    //     // 处理特定流的远端音频数据...
    //     if(mounted){
    //       final noZegoLength = this.countValuesGreaterThanZero(data);
    //       print('🚩 emmmmmm onPlayerAudioData, length:$noZegoLength/$length streamID:$streamID ${param.channel} ${param.sampleRate}');
    //       processRemoteAudio(
    //         data,
    //         rightLanguage['code'], // 使用左侧选择的语言识别
    //       );
    //     }
    // });
    //
    // ZegoExpressEngine.onPlaybackAudioData = ((data, length, param) {
    //   final noZegoLength = this.countValuesGreaterThanZero(data);
    //   print(
    //       '🚩 fffflutter onPlaybackAudioData, length:$noZegoLength/$length ${param.channel} ${param.sampleRate}');
    // });
    // ZegoExpressEngine.onCapturedAudioData = ((data, length, param) {
    //   final noZegoLength = this.countValuesGreaterThanZero(data);
    //   print(
    //       '🚩 fffflutter onCapturedAudioData, length:$noZegoLength/$length ${param.channel} ${param.sampleRate}');
    //     // 处理本地PCM音频数据...
    //     if(mounted){
    //       processLocalAudio(
    //         data,
    //         leftLanguage['code'], // 使用左侧选择的语言识别
    //       );
    //     }
    // });
  }

  int countValuesGreaterThanZero(Uint8List list) {
    int count = 0;
    for (int value in list) {
      if (value > 0) {
        count++;
      }
    }
    return count;
  }

  // Join a channel
  Future<void> loginRoom() async {
    if (!_isEngineActive) {
      print('⚠️ 引擎未初始化，无法登录房间');
      return;
    }
    // Instantiate a ZegoUser object
    _localZegoUser = ZegoUser(ZegoConfig.instance.userID, ZegoConfig.instance.userName);
    ZegoRoomConfig config = ZegoRoomConfig.defaultConfig();
    config.isUserStatusNotify = true;
    final token = (await generateZegoToken(ZegoConfig.instance.appID, _localZegoUser.userID, ZegoConfig.instance.secret, 3600, ""))!;
    config.token = token;
    try {
      if (kIsWeb) {
        await ZegoExpressEngine.instance.loginRoom(ZegoConfig.instance.room, _localZegoUser, config: config);
      } else {
        await ZegoExpressEngine.instance.loginRoom(ZegoConfig.instance.room, _localZegoUser, config: config);
      }
      print('✅ 成功登录房间: ${ZegoConfig.instance.room}');
      // 登录后立即启动预览
      await startPreview();
      await ZegoExpressEngine.instance.muteMicrophone(false);
      await startPublishingStream(_localZegoUser.userID);
    } catch (e) {
      print('❌ 登录房间失败: $e');
    }
  }

  Future<void> logoutRoom() async{
    // Logout room will automatically stop publishing/playing stream.
    //
    // But directly logout room without destroying the [PlatformView]
    // or [TextureRenderer] may cause a memory leak.
    await ZegoExpressEngine.instance.logoutRoom(ZegoConfig.instance.room);
    print('🚪 logout room, roomID: $ZegoConfig.instance.room');

    clearPreviewView();
    clearPlayView();
  }

  // MARK: - Step 3: StartPublishingStream
  Future<void> startPreview() async{
    Future<void> _startPreview(int viewID) async {
      ZegoCanvas canvas = ZegoCanvas.view(viewID);
      await ZegoExpressEngine.instance.startPreview(canvas: canvas);
      print('🔌 Start preview, viewID: $viewID');
      await _localRTASR.startChannel();
    }

    if (kIsWeb) {
      ZegoExpressEngine.instance.createCanvasView((viewID) {
        _previewViewID = viewID;
        _startPreview(viewID);
      }).then((widget) {
        setState(() {
          _previewViewWidget = widget;
        });
      });
    } else {
      ZegoExpressEngine.instance.startPreview();
    }
  }

  Future<void> clearPreviewView() async{
    if (!kIsWeb) {
      return;
    }

    if (_previewViewWidget == null) {
      return;
    }

    // Developers should destroy the [CanvasView] after
    // [stopPublishingStream] or [stopPreview] to release resource and avoid memory leaks
    await ZegoExpressEngine.instance.destroyCanvasView(_previewViewID);
    await _localRTASR.stopWriteData();
    setState(() => _previewViewWidget = null);
  }

  Future<void> clearPlayView() async{
    if (!kIsWeb) {
      return;
    }

    if (_playViewWidget == null) {
      return;
    }

    // Developers should destroy the [CanvasView]
    // after [stopPlayingStream] to release resource and avoid memory leaks
    await ZegoExpressEngine.instance.destroyCanvasView(_playViewID);
    setState(() => _playViewWidget = null);
  }

  Future<void> stopPreview() async{
    if (!kIsWeb) {
      return;
    }

    if (_previewViewWidget == null) {
      return;
    }

    await ZegoExpressEngine.instance.stopPreview();
    await clearPreviewView();
  }

  Future<void> startPublishingStream(String streamID) async{
    // _mediaPlayer ??= await ZegoExpressEngine.instance.createMediaPlayer();
    // await _mediaPlayer?.enableAudioData(true);
    // await _mediaPlayer?.start();
    await ZegoExpressEngine.instance.startPublishingStream(streamID);
    print('📤 Start publishing stream, streamID: $streamID');
  }

  Future<void> stopPublishingStream() async{
    // _mediaPlayer?.stop();
    // if (_mediaPlayer != null) {
    //   Timer(Duration(seconds: 1), () {
    //     ZegoExpressEngine.instance.destroyMediaPlayer(_mediaPlayer!);
    //     _mediaPlayer = null;
    //   });
    // }
    await ZegoExpressEngine.instance.stopPublishingStream();
  }

  // MARK: - Step 4: StartPlayingStream

  Future<void> startPlayingStream(String streamID) async{
    void _startPlayingStream(int viewID, String streamID) async{
      ZegoCanvas canvas = ZegoCanvas.view(viewID);
      ZegoExpressEngine.instance.startPlayingStream(streamID, canvas: canvas);
      print('📥 Start playing stream, streamID: $streamID, viewID: $viewID');
      await _remoteRTASR.startChannel();
    }

    if (kIsWeb) {
      print('📥 Start playing stream, streamID');
      ZegoExpressEngine.instance.createCanvasView((viewID) {
        _playViewID = viewID;
        _startPlayingStream(viewID, streamID);
      }).then((widget) {
        setState(() {
          _playViewWidget = widget;
        });
      });
    } else {
      await ZegoExpressEngine.instance.startPlayingStream(streamID);
    }
  }

  Future<void> stopPlayingStream(String streamID) async{
    await ZegoExpressEngine.instance.stopPlayingStream(streamID);
    await clearPlayView();
    await _remoteRTASR.stopWriteData();
  }

  // MARK: - Exit

  Future<void> destroyEngine() async {
    await ZegoExpressEngine.instance.stopAudioDataObserver();
    await stopPreview();
    await clearPreviewView();
    await clearPlayView();

    // Can destroy the engine when you don't need audio and video calls
    //
    // Destroy engine will automatically logout room and stop publishing/playing stream.
    await ZegoExpressEngine.destroyEngine()
        .then((ret) => print('already destroy engine'));

    print('🏳️ Destroy ZegoExpressEngine');

    // Notify View that engine state changed
    setState(() {
      _isEngineActive = false;
      _roomState = ZegoRoomState.Disconnected;
      _publisherState = ZegoPublisherState.NoPublish;
      _playerState = ZegoPlayerState.NoPlay;
    });
  }

  // 处理本地麦克风音频
  Future<void> processLocalAudio(Uint8List pcmData, String lang) async {
    if (_localRTASR.isFirst) {
      ConversationMessage message = ConversationMessage(
        originalText: "",
        translatedText: "",
        ttsFilePath: "",
        isPlaying: false,
        isTalking: false,
        isLeft: false,
      );
      ref.read(conversationProviderTranslate.notifier).addMessage(message);
      curNearMessage = message;
      _localRTASR.onResult = (partialResult) {
        if (mounted) {  // Check if the widget is still mounted
          logger.d("emmmmmm 中间结果: $partialResult");
          curNearMessage?.originalText = partialResult;
          ref.read(conversationProviderTranslate.notifier).updateMessage(curNearMessage!);
          scrollToEnd();
        }
      };
      _localRTASR.onEndResult = (finalResult) {
        if (mounted) {  // Check if the widget is still mounted
          logger.d("emmmmmm 最终结果: $finalResult");
          // Handle final result
          _handleFinalResult(finalResult, curNearMessage!, false, ref);
          ConversationMessage newMessage = ConversationMessage(
            originalText: "",
            translatedText: "",
            ttsFilePath: "",
            isPlaying: false,
            isTalking: false,
            isLeft: false,
          );
          ref.read(conversationProviderTranslate.notifier).addMessage(newMessage);
          curNearMessage = newMessage;
          scrollToEnd();
        }
      };
    }
    _localRTASR.writeAudioData(lang, 1, pcmData);
  }

  // 处理远端用户音频
  void processRemoteAudio(Uint8List pcmData, String lang) {
    if (_remoteRTASR.isFirst) {
      ConversationMessage message = ConversationMessage(
        originalText: "",
        translatedText: "",
        ttsFilePath: "",
        isPlaying: false,
        isTalking: false,
        isLeft: true,
      );
      ref.read(conversationProviderTranslate.notifier).addMessage(message);
      curFarMessage = message;
      _remoteRTASR.onResult = (partialResult) {
        if (mounted) {  // Check if the widget is still mounted
          logger.d("emmmmmm 远端中间结果: $partialResult");
          curFarMessage?.originalText = partialResult;
          ref.read(conversationProviderTranslate.notifier).updateMessage(curFarMessage!);
          scrollToEnd();
        }
      };
      _remoteRTASR.onEndResult = (finalResult) {
        if (mounted) {  // Check if the widget is still mounted
          logger.d("emmmmmm 远端最终结果: $finalResult");
          // Handle final result
          _handleFinalResult(finalResult, curFarMessage!, true, ref);
          ConversationMessage newMessage = ConversationMessage(
            originalText: "",
            translatedText: "",
            ttsFilePath: "",
            isPlaying: false,
            isTalking: false,
            isLeft: true,
          );
          ref.read(conversationProviderTranslate.notifier).addMessage(newMessage);
          curFarMessage = newMessage;
          scrollToEnd();
        }
      };
    }
    _remoteRTASR.writeAudioData(lang, 0, pcmData);
  }

  Uint8List convertFloat32ToInt16(Uint8List float32Bytes) {
    final float32List = float32Bytes.buffer.asFloat32List();
    final int16List = Int16List(float32List.length);

    for (int i = 0; i < float32List.length; i++) {
      double sample = float32List[i];

      // Clamp between -1.0 and 1.0 (safe range)
      if (sample < -1.0) sample = -1.0;
      if (sample > 1.0) sample = 1.0;

      // Scale to 16-bit PCM range
      int16List[i] = (sample * 32767).toInt();
    }

    return Uint8List.view(int16List.buffer);
  }


  bool isAllZero(Uint8List? buffer) {
    if (buffer == null) return false;
    for (int i = 0; i < buffer.length; i++) {
      if (buffer[i] != 0) {
        return false;
      }
    }
    return true;
  }


  //切换摄像头（前后摄像头）
  Future<void> toggleCamera() async{
    setState(() {
      isFrontCamera = !isFrontCamera;
    });
    ZegoExpressEngine.instance.useFrontCamera(isFrontCamera);
  }

  //控制麦克风开启与关闭
  Future<void> toggleMic() async{
    setState(() {
      isMicMuted = !isMicMuted;
    });
    ZegoExpressEngine.instance.muteMicrophone(isMicMuted);
  }

  //控制视频流的开启与关闭
  Future<void> toggleCameraStream() async {
    print("控制视频流的开启与关闭 $isVideoMuted");

    setState(() {
      isVideoMuted = !isVideoMuted;
    });
    ZegoExpressEngine.instance.enableCamera(!isVideoMuted);
  }


  //退出当前频道
  Future<void> exitChannel() async{
    ref.read(conversationProviderTranslate.notifier).clearMessages();
    Navigator.pop(context); // 返回到上一个页面
  }

  //控制扬声器的开启与关闭
  Future<void> toggleSpeaker() async{
    setState(() {
      isSpeakerEnabled = !isSpeakerEnabled;
    });
    ZegoExpressEngine.instance.muteSpeaker(!isSpeakerEnabled);

  }


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.resumed: //Switch from the background to the foreground, and the interface is visible
        break;
      case AppLifecycleState.paused: // Interface invisible, background
      // 当应用进入后台时停止播放
      //   audioPlayerUtil.stop();
        break;
      case AppLifecycleState.detached:
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

// Displays local video view
  Widget _localVideo() {
    print("_previewViewWidget:$_previewViewWidget");
    return _previewViewWidget ?? Container(color: Colors.white); // If null, return a black container
  }

// Display remote user's video
  Widget _remoteVideo() {
    print("_playViewWidget:$_playViewWidget");
    return _playViewWidget ?? Container(color: Colors.black); // If null, return a black container
  }



  @override
  void dispose() {
    // audioPlayerUtil.stop();
    _cleanupEngine();
    super.dispose();
  }


  // Leaves the channel and releases resources
  Future<void> _cleanupEngine() async {
    WidgetsBinding.instance.removeObserver(this);
    stopListenEvent();
    _localRTASR.stopWriteData();
    _remoteRTASR.stopWriteData();
    ZegoExpressEngine.destroyEngine()
        .then((value) => print('async destroy success'));
  }

  void stopListenEvent() {
    ZegoExpressEngine.onRoomUserUpdate = null;
    ZegoExpressEngine.onRoomStreamUpdate = null;
    ZegoExpressEngine.onRoomStateUpdate = null;
    ZegoExpressEngine.onPublisherStateUpdate = null;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(conversationProviderTranslate);
    return Scaffold(
      backgroundColor: Colors.black54,
      key: _scaffoldKey,
      body: WillPopScope(
        onWillPop: () async {
          // _trtcCloud.exitRoom();
          return true;
        },
        child: Column(
          children: [

            // 顶部栏
            Expanded(
              flex: 1,
              child: _buildTopBar(context),
            ),

            // 视频区域 + 浮层内容
            Expanded(
              flex: 9,
              child: Stack(
                children: [
                  // 远程视频全屏显示（_buildTopBar 下面）
                  Positioned.fill(
                    child: _remoteVideo(),
                  ),

                  // 本地视频浮动在右上角
                  Positioned(
                    top: 0,
                    right: 20,
                    width: 150,
                    height: 200,
                    child: !isVideoMuted
                        ? _localVideo()
                        : const Center(
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.black,
                          child: Icon(Icons.person, size: 40, color: Colors.white),
                        )
                    ),
                  ),

                  // 中间内容 + 底部栏合并为一个Align + Column
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min, // 内容多高就多高，避免撑满整个Stack
                      children: [
                        // 中间分享按钮或对话列表
                        _buildConversationList(),

                        // 底部栏
                        SizedBox(
                          child: _buildBottomBar(),
                        ),
                      ],
                    ),
                  ),

                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildTopBar(BuildContext context) {
    final selectionState =
    ref.watch(languageSelectionProvider("VedioCall"));
    final selectionNotifier =
    ref.read(languageSelectionProvider("VedioCall").notifier);
    return Consumer(
      builder: (context, watch, _) {
        final languageState = ref.watch(languageProvider);
        final localization = AppLocalizations.of(context)!;
        print("languageState$languageState");
        if (languageState is AsyncLoading) {
          return Center(child: CircularProgressIndicator());
        } else if (languageState is AsyncError) {
          return Center(child: Text(localization.translate('加载语言失败')));
        } else if (languageState is AsyncData) {
          final leftLanguage = selectionNotifier.getLeftSelectedLanguage();
          final rightLanguage = selectionNotifier.getRightSelectedLanguage();

          print("leftLanguage: $leftLanguage");

          return Padding(
            padding: const EdgeInsets.only(top: 12.0, bottom: 8),
            // 移除左右的 padding
            child: Row(
              children: [
                // 返回按钮固定在左侧
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    ref.read(conversationProviderTranslate.notifier).clearMessages();
                    Navigator.pop(context);
                  },
                ),
                // 其他内容居中
                Expanded(
                  child: Center(
                    // 将其他内容居中
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center, // 居中对齐
                      children: [
                        _buildLanguageButtonWithIcon(
                          text: leftLanguage.isEmpty
                              ? "中文"
                              : leftLanguage['displayName'] ?? "中文",
                          onPressed: () => _onLanguageButtonPressed(
                              context, selectionState.leftLanguageIndex,
                                  (index) {
                                ref
                                    .read(languageSelectionProvider("VedioCall")
                                    .notifier)
                                    .selectLeftLanguage(index);
                              }),
                          isEnabled: !(isLeftRecording || isRightRecording),
                        ),
                        const SizedBox(width: 10),
                        _buildLanguageSwapButton(
                          isEnabled: !(isLeftRecording || isRightRecording),
                        ),
                        const SizedBox(width: 10),
                        _buildLanguageButtonWithIcon(
                          text: rightLanguage.isEmpty
                              ? "英文"
                              : rightLanguage['displayName'] ?? "English",
                          onPressed: () => _onLanguageButtonPressed(
                              context, selectionState.rightLanguageIndex,
                                  (index) {
                                final not = ref
                                    .read(languageSelectionProvider(
                                    "VedioCall")
                                    .notifier);
                                not.selectRightLanguage(index);
                              }),
                          isEnabled: !(isLeftRecording || isRightRecording),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return SizedBox.shrink();
      },
    );
  }

  Widget _buildLanguageButtonWithIcon({
    required String text,
    required VoidCallback onPressed,
    bool isEnabled = true, // 录音时禁用
  }) {
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5, // 禁用时降低透明度
      child: TextButton(
        onPressed: isEnabled ? onPressed : null, // 禁用时 `onPressed` 设为 `null`
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                constraints: BoxConstraints(maxWidth: 80),
                child: Text(
                  text,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_drop_down, size: 20, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageSwapButton({bool isEnabled = true}) {
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5, // 禁用时降低透明度
      child: GestureDetector(
        onTap: isEnabled
            ? () {
          ref
              .read(
              languageSelectionProvider("VedioCall").notifier)
              .swapLanguages();
        }
            : null, // 禁用时不执行点击事件
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(25),
          ),
          width: 60,
          height: 30,
          padding: const EdgeInsets.all(1),
          child: const Icon(Icons.swap_horiz, color: Colors.blue),
        ),
      ),
    );
  }

  void _onLanguageButtonPressed(
      BuildContext context, int index, Function(int) callback) {
    // 左右应不能选择同一种语言
    final selectionNotifier =
    ref.read(languageSelectionProvider("VedioCall").notifier);
    final leftLanguage = selectionNotifier.getLeftSelectedLanguage();
    final rightLanguage = selectionNotifier.getRightSelectedLanguage();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LanguageSelectionScreen(
          pageKey: "VedioCall",
          currentIndex: index,
          // 左右应不能选择同一种语言
          callback: (selectedIndex) {
            // 获取选择的语言
            final selectedLanguage =
            selectionNotifier.state.getLanguage(selectedIndex);

            // 检查是否与另一侧的语言相同
            if ((index == selectionNotifier.state.leftLanguageIndex &&
                selectedLanguage['code'] == rightLanguage['code']) ||
                (index == selectionNotifier.state.rightLanguageIndex &&
                    selectedLanguage['code'] == leftLanguage['code'])) {
              // 提示用户选择不同的语言
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content:
                Text(AppLocalizations.of(context)!.translate("请选择不同的语言")),
                duration: Duration(seconds: 2),
              ));
            } else {
              // 更新选择
              callback(selectedIndex);
            }
          },
        ),
      ),
    );
  }

  Widget _buildConversationList() {
    return Expanded(
      child: Consumer(
        builder: (context, ref, _) {
          final conversation = ref.watch(conversationProviderTranslate);
          //自动滚动到列表的最后
          WidgetsBinding.instance.addPostFrameCallback((_) {
            scrollToEnd();
          });
          final playingFilePath =
              ref.watch(conversationProviderTranslate.notifier).playingFilePath;
          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            itemCount: conversation.length,
            itemBuilder: (context, index) {
              final message = conversation[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: message.isLeft
                    ? MessageContentLeft(
                    originalText: message.originalText,
                    translatedText: message.translatedText,
                    ttsFilePath: message.ttsFilePath,
                    isPlaying: message.isPlaying,
                    isTalking: message.isTalking,
                    playingFilePath: playingFilePath,
                    onPlay: () => _onPlay(message, ref),
                    onStop: () => _onStop(message, ref),
                    originalTextColor: null,
                    isAutoPlaying: message.isAutoPlaying)
                    : MessageContentRight(
                    originalText: message.originalText,
                    translatedText: message.translatedText,
                    ttsFilePath: message.ttsFilePath,
                    isPlaying: message.isPlaying,
                    isTalking: message.isTalking,
                    playingFilePath: playingFilePath,
                    onPlay: () => _onPlay(message, ref),
                    onStop: () => _onStop(message, ref),
                    isAutoPlaying: message.isAutoPlaying),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60.0,horizontal: 10.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // 顶部两按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildBottomImageButton(
                iconUrl: isFrontCamera ? 'assets/images/ttai/ic_veidocall_camera_btn.png' : 'assets/images/ttai/ic_veidocall_camera_switch_btn.png',
                onPressed: toggleCamera,
              ),
              _buildBottomImageButton(
                iconUrl: '',
                onPressed: () {

                },
              ),
              _buildBottomImageButton(
                iconUrl: isVideoMuted ? 'assets/images/ttai/ic_veidocall_vedio_off_btn.png' : 'assets/images/ttai/ic_veidocall_vedio_btn.png',
                onPressed: toggleCameraStream,
              ),
            ],
          ),
          SizedBox(height: 20), // 上下间距
          // 底部三按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center, // 确保对齐方式一致

            children: [
              _buildBottomImageButton(
                iconUrl: isMicMuted ? 'assets/images/ttai/ic_veidocall_mic_off_btn.png' : 'assets/images/ttai/ic_veidocall_mic_btn.png' ,
                onPressed: toggleMic,
              ),
              _buildBottomImageButton(
                iconUrl: 'assets/images/ttai/ic_veidocall_exit_btn.png',
                onPressed: exitChannel,
              ),
              _buildBottomImageButton(
                iconUrl: isSpeakerEnabled ? 'assets/images/ttai/ic_veidocall_volume_btn.png' : 'assets/images/ttai/ic_veidocall_volume_off_btn.png',
                onPressed: toggleSpeaker,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomImageButton({
    required String iconUrl,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 60,  // 设置按钮的宽度
        height: 60, // 设置按钮的高度
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30), // 设置圆角效果
          color: iconUrl.isEmpty ? Colors.transparent : Colors.grey, // 如果是空按钮，设置为透明
        ),
        child: iconUrl.isNotEmpty
            ? Image.asset(
          iconUrl,
          width: 60,  // 设置图像的宽度
          height: 60, // 设置图像的高度
          fit: BoxFit.contain,
        )
            : null,  // 空按钮没有图片
      ),
    );
  }

  void _onPlay(ConversationMessage message, WidgetRef ref) {
    // // 停止录音并显示已识别的内容
    // if (isLeftRecording || isRightRecording) {
    //   _stopASR();
    //   _onStop(message, ref);
    // }
    //
    // // 当最新消息正在自动播放时，如果点击上面的对话内容的按钮，停止播放和动画
    // if (curFarMessage != null) {
    //   curFarMessage!.isAutoPlaying = false;
    //   curFarMessage!.isPlaying = false;
    //   ref
    //       .read(conversationProviderTranslate.notifier)
    //       .updateMessage(curFarMessage!);
    // }
    //
    // final notifier = ref.read(conversationProviderTranslate.notifier);
    //
    // // 如果有其他音频在播放，先停止
    // if (notifier.playingFilePath != null) {
    //   audioPlayerUtil.stop();
    // }
    // curFarMessage?.isPlaying = false;
    // curFarMessage?.isAutoPlaying = false;
    // notifier.updateMessage(curFarMessage!);
    // curFarMessage = message;
    // // 设置新的播放状态
    // notifier.setPlayingFilePath(message.ttsFilePath);
    // message.isPlaying = true;
    // message.isAutoPlaying = true; // Start animation
    // notifier.updateMessage(message);
    //
    // audioPlayerUtil.playPCMFromFile(message.ttsFilePath, () {
    //   // 播放完毕后清除状态
    //   message.isPlaying = false;
    //   message.isAutoPlaying = false;
    //   notifier.setPlayingFilePath(null);
    //   notifier.updateMessage(message);
    // });
  }

  void _onStop(ConversationMessage message, WidgetRef ref) {
    // final notifier = ref.read(conversationProviderTranslate.notifier);
    //
    // audioPlayerUtil.stop();
    // message.isPlaying = false;
    // message.isAutoPlaying = false;
    // notifier.setPlayingFilePath(null);
    // notifier.updateMessage(message);
  }


  void _handleFinalResult(String finalResult, ConversationMessage message,
      bool isLeft, WidgetRef ref) {
    if (finalResult.isEmpty) {
      ref.read(conversationProviderTranslate.notifier).removeMessage(message);
    } else {
      message.originalText = finalResult;
      ref.read(conversationProviderTranslate.notifier).updateMessage(message);
      XunFeiMachineTranslation.sendMessage(
        finalResult,
        isLeft
            ? ref
            .read(languageSelectionProvider("VedioCall").notifier)
            .getRightSelectedLanguage()['code']
            : ref
            .read(languageSelectionProvider("VedioCall").notifier)
            .getLeftSelectedLanguage()['code'],
        isLeft
            ? ref
            .read(languageSelectionProvider("VedioCall").notifier)
            .getLeftSelectedLanguage()['code']
            : ref
            .read(languageSelectionProvider("VedioCall").notifier)
            .getRightSelectedLanguage()['code'],
            (result) {
          print("reslut:$result,isLeft$isLeft");
          message.translatedText = result;
          ref
              .read(conversationProviderTranslate.notifier)
              .updateMessage(message);
          // tts
          // tts.startTTS(
          //     result,
          //     isLeft
          //         ? ref
          //         .read(languageSelectionProvider("VedioCall")
          //         .notifier)
          //         .getRightSelectedLanguage()['voice']
          //         : ref
          //         .read(languageSelectionProvider("VedioCall")
          //         .notifier)
          //         .getLeftSelectedLanguage()['voice'], (filepath) {
          //   message.ttsFilePath = filepath;
          //   ref
          //       .read(conversationProviderTranslate.notifier)
          //       .updateMessage(message);
          //
          //   // 检查是否有正在播放的消息
          //   final notifier = ref.read(conversationProviderTranslate.notifier);
          //   if (notifier.playingFilePath != null) {
          //     // 如果有正在播放的消息，等待它播放完成后再播放新消息
          //     message.isPlaying = false;
          //     message.isAutoPlaying = false;
          //     ref
          //         .read(conversationProviderTranslate.notifier)
          //         .updateMessage(message);
          //
          //     // 监听当前播放的消息状态
          //     final currentPlayingMessage = ref
          //         .read(conversationProviderTranslate)
          //         .firstWhere(
          //             (msg) => msg.ttsFilePath == notifier.playingFilePath);
          //
          //     // 创建一个定时器来检查播放状态
          //     Timer.periodic(Duration(milliseconds: 100), (timer) {
          //       if (!currentPlayingMessage.isPlaying) {
          //         timer.cancel();
          //         // 当前消息播放完成，开始播放新消息
          //         message.isPlaying = true;
          //         message.isAutoPlaying = true;
          //         ref
          //             .read(conversationProviderTranslate.notifier)
          //             .updateMessage(message);
          //         curMessage = message;
          //         audioPlayerUtil.playPCMFromFile(filepath, () {
          //           message.isPlaying = false;
          //           message.isAutoPlaying = false;
          //           ref
          //               .read(conversationProviderTranslate.notifier)
          //               .updateMessage(message);
          //         });
          //       }
          //     });
          //   } else {
          //     // 如果没有正在播放的消息，直接播放新消息
          //     message.isPlaying = true;
          //     message.isAutoPlaying = true;
          //     ref
          //         .read(conversationProviderTranslate.notifier)
          //         .updateMessage(message);
          //     curMessage = message;
          //     audioPlayerUtil.playPCMFromFile(filepath, () {
          //       message.isPlaying = false;
          //       message.isAutoPlaying = false;
          //       ref
          //           .read(conversationProviderTranslate.notifier)
          //           .updateMessage(message);
          //     });
          //   }
          // }, () {}, false);
        },
            (error) {
          print("翻译失败: $error");
        },
      );
    }
    scrollToEnd();
  }


  void scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }
}