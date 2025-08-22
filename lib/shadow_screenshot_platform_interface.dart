import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'shadow_screenshot_method_channel.dart';

abstract class ShadowScreenshotPlatform extends PlatformInterface {
  /// Constructs a ShadowScreenshotPlatform.
  ShadowScreenshotPlatform() : super(token: _token);

  static final Object _token = Object();

  static ShadowScreenshotPlatform _instance = MethodChannelShadowScreenshot();

  /// The default instance of [ShadowScreenshotPlatform] to use.
  ///
  /// Defaults to [MethodChannelShadowScreenshot].
  static ShadowScreenshotPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [ShadowScreenshotPlatform] when
  /// they register themselves.
  static set instance(ShadowScreenshotPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Stream<dynamic> get screenshotEvents {
    throw UnimplementedError('screenshotEvents has not been implemented.');
  }

  Stream<dynamic> screenshotEventsWithParams([Map<String, dynamic>? params]) {
    throw UnimplementedError('screenshotEventsWithParams has not been implemented.');
  }

  Future<void> screenshot() {
    throw UnimplementedError('screenshot() has not been implemented.');
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
