import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'shadow_screenshot_platform_interface.dart';

/// An implementation of [ShadowScreenshotPlatform] that uses method channels.
class MethodChannelShadowScreenshot extends ShadowScreenshotPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('shadow_screenshot');

  @visibleForTesting
  final screenshotEventChannel = const EventChannel('shadow_screenshot_events');

  @override
  Stream<dynamic> get screenshotEvents => screenshotEventChannel.receiveBroadcastStream();

  @override
  Stream<dynamic> screenshotEventsWithParams([Map<String, dynamic>? params]) {
    return screenshotEventChannel.receiveBroadcastStream(params);
  }

  @override
  Future<void> screenshot() async {
    await methodChannel.invokeMethod('screenshot');
  }

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
