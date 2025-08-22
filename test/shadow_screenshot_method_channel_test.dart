import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_screenshot/shadow_screenshot_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelShadowScreenshot platform = MethodChannelShadowScreenshot();
  const MethodChannel channel = MethodChannel('shadow_screenshot');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
