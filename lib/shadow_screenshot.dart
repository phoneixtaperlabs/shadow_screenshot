import 'shadow_screenshot_platform_interface.dart';

class ShadowScreenshot {
  Stream<dynamic> screenshotEventsWithParams([Map<String, dynamic>? params]) {
    return ShadowScreenshotPlatform.instance.screenshotEventsWithParams(params);
  }

  Stream<dynamic> get screenshotEvents {
    return ShadowScreenshotPlatform.instance.screenshotEvents;
  }

  Future<void> screenshot() {
    return ShadowScreenshotPlatform.instance.screenshot();
  }

  Future<String?> getPlatformVersion() {
    return ShadowScreenshotPlatform.instance.getPlatformVersion();
  }
}
