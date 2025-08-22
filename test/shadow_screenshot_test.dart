import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_screenshot/shadow_screenshot.dart';
import 'package:shadow_screenshot/shadow_screenshot_platform_interface.dart';
import 'package:shadow_screenshot/shadow_screenshot_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockShadowScreenshotPlatform
    with MockPlatformInterfaceMixin
    implements ShadowScreenshotPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final ShadowScreenshotPlatform initialPlatform = ShadowScreenshotPlatform.instance;

  test('$MethodChannelShadowScreenshot is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelShadowScreenshot>());
  });

  test('getPlatformVersion', () async {
    ShadowScreenshot shadowScreenshotPlugin = ShadowScreenshot();
    MockShadowScreenshotPlatform fakePlatform = MockShadowScreenshotPlatform();
    ShadowScreenshotPlatform.instance = fakePlatform;

    expect(await shadowScreenshotPlugin.getPlatformVersion(), '42');
  });
}
