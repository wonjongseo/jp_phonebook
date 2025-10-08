import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:jg_phonebook/services/navite/ios/ios_native_service.dart';
import 'package:jg_phonebook/services/navite/aos_native_service.dart';

/// ===============================
/// NativeService 추상 클래스 + 플랫폼 구현
/// ===============================
abstract class NativeService {
  /// 앱 시작 시 자동 호출: 플랫폼별 필수 권한/상태 체크 & 요청
  Future<void> init() async {}

  /// 라벨 변경 시 플랫폼별 후처리
  Future<void> onLabelsChanged() async => _unsupported('onLabelsChanged');

  /// iOS: Hive → CallDirectory 동기화
  Future<void> syncFromHive() async => _unsupported('syncFromHive');

  /// iOS: 확장 리로드
  Future<bool> reload() async => _unsupported('reload');

  /// Android: 권한/예외 요청(READ_PHONE_STATE/POST_NOTIFICATIONS(13+)/OVERLAY/Battery)
  Future<void> requestPlatformPermissions() async =>
      _unsupported('requestPlatformPermissions');

  /// Android: 오버레이 제어
  Future<void> startOverlay(String number) async =>
      _unsupported('startOverlay');
  Future<void> stopOverlay() async => _unsupported('stopOverlay');

  /// iOS: 상태 조회/안내
  Future<String> getStatus() async => _unsupported('getStatus');
  Future<void> ensureEnabledOrPrompt(BuildContext context) async =>
      _unsupported('ensureEnabledOrPrompt');

  static T _unsupported<T>(String fn) {
    throw UnsupportedError(
      'NativeService.$fn is not supported on this platform',
    );
  }

  static final NativeService instance =
      Platform.isIOS ? IosNativeService() : AosNativeService();
}
