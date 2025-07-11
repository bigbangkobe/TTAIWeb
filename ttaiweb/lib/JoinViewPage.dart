import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ttaiweb/quick_start_page.dart';
import 'package:universal_html/html.dart' as html;

import 'AppLocalizations.dart';
import 'VideoCallPage.dart';


class JoinViewPage extends ConsumerStatefulWidget {
  const JoinViewPage({super.key});

  @override
  ConsumerState<JoinViewPage> createState() => _JoinViewPageState();
}

class _JoinViewPageState extends ConsumerState<JoinViewPage> {
  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(localization.translate('加入房间')),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            const SizedBox(height: 20), // Adding some space
            // Join Room Button
            ElevatedButton.icon(
              icon: const Icon(Icons.video_call), // Video icon
              label: Text(localization.translate('加入房间')),
              onPressed: () async{
                if (html.window.navigator.mediaDevices?.getUserMedia != null) {
                  // 设备支持 getUserMedia
                  print('getUserMedia is supported!');
                  try {
                    final mediaStream = await html.window.navigator.getUserMedia(
                      audio: true,
                      video: true,
                    );
                    print('Media stream obtained$mediaStream');
                  } catch (e) {
                    print('Error: $e');
                  }
                } else {
                  print('getUserMedia is not supported in this browser');
                }
                // Navigate to VideoCallPage when the button is pressed
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    // builder: (context) => QuickStartPage(),
                    builder: (context) => const VideoCallPage(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.blue, // Button text color
              ),
            ),
          ],
        ),
      ),
    );
  }
}
