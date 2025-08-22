import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:shadow_screenshot/shadow_screenshot.dart';
import 'package:uuid/uuid.dart';

void main() {
  runApp(const MyApp());
}

class MyUUID {
  static String createUUID() {
    return const Uuid().v4().replaceAll('-', '');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  final _shadowScreenshotPlugin = ShadowScreenshot();
  StreamSubscription<dynamic>? screenshotEvents;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> startListeningToScreenshotEvents() async {
    if (_isListening) return;

    try {
      await screenshotEvents?.cancel();

      final imageOptions = {
        'format': 'jpeg',
        'quality': 0.3,
        // 'resize': {'mode': 'fit', 'maxWidth': 1200, 'maxHeight': 1200},
      };

      final params = {'convUUID': MyUUID.createUUID(), 'interval': 3.0, 'imageOptions': imageOptions};

      screenshotEvents = _shadowScreenshotPlugin
          .screenshotEventsWithParams(params)
          .listen(
            (event) {
              print('Screenshot event received: $event');
              // Handle the screenshot event here
            },
            onError: (error) {
              print('Error receiving screenshot event: $error');
              setState(() {
                _isListening = false;
              });
            },
            onDone: () {
              print('Screenshot event stream closed');
              setState(() {
                _isListening = false;
              });
            },
          );

      setState(() {
        _isListening = true;
      });
      print('Started listening to screenshot events');
    } catch (e) {
      print('Failed to start listening: $e');
      setState(() {
        _isListening = false;
      });
    }
  }

  Future<void> stopListeningToScreenshotEvents() async {
    if (!_isListening) return;

    try {
      await screenshotEvents?.cancel();
      screenshotEvents = null;

      setState(() {
        _isListening = false;
      });
      print('Stopped listening to screenshot events');
    } catch (e) {
      print('Error stopping screenshot events: $e');
      screenshotEvents = null;
      setState(() {
        _isListening = false;
      });
    }
  }

  Future<void> takeScreenshot() async {
    try {
      await _shadowScreenshotPlugin.screenshot();
      print('Screenshot taken successfully.');
    } catch (e) {
      print('Error taking screenshot: $e');
    }
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion = await _shadowScreenshotPlugin.getPlatformVersion() ?? 'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  @override
  void dispose() {
    screenshotEvents?.cancel();
    screenshotEvents = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Plugin example app')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Running on: $_platformVersion\n'),
              const SizedBox(height: 20),
              Text(
                'Screenshot Listening: ${_isListening ? "Active" : "Inactive"}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _isListening ? Colors.green : Colors.red),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(onPressed: _isListening ? null : startListeningToScreenshotEvents, child: const Text('Start Listening')),
                  ElevatedButton(onPressed: _isListening ? stopListeningToScreenshotEvents : null, child: const Text('Stop Listening')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
