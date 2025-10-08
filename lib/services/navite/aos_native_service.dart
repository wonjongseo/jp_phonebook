import 'dart:async';
import 'package:jg_phonebook/core/constants.dart';
import 'package:jg_phonebook/services/navite/native_service.dart';

/// ===============================
/// Android 구현
class AosNativeService extends NativeService {
  AosNativeService();

  @override
  Future<void> init() async {
    // 앱 시작 시 필수 권한 자동 요청 (네이티브 로직이 내부에서 "미허용만" 요청하도록 구현되어 있다고 가정)
    await requestPlatformPermissions();
  }

  @override
  Future<void> requestPlatformPermissions() async {
    await kAndroidOverlayChannel.invokeMethod('requestRuntimePermissions');
    await kAndroidOverlayChannel.invokeMethod('requestOverlayPermission');
    await kAndroidOverlayChannel.invokeMethod('requestBatteryException');
  }

  @override
  Future<void> startOverlay(String number) async {
    await kAndroidOverlayChannel.invokeMethod('startDummyOverlay', {
      'number': number,
    });
  }

  @override
  Future<void> stopOverlay() async {
    await kAndroidOverlayChannel.invokeMethod('stopOverlay');
  }

  @override
  Future<void> onLabelsChanged() async {
    // 네이티브 수정 없이 최신 반영:
    // → headless lookupMain 이 매 조회마다 Hive 박스를 재오픈하므로 별도 알림 불필요.
    return;
  }
}
