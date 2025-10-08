// lib/common/permission/permission_service.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class PermissionService {
  /// 통화/통화기록 권한 (Android 전용)
  static Future<bool> requestPhoneAndCallLog() async {
    if (!Platform.isAndroid) return true; // iOS에선 통화기록 자체를 안 씀

    // Manifest에 READ_PHONE_STATE, READ_CALL_LOG, READ_PHONE_NUMBERS 선언 필수
    final statuses =
        await [
          Permission.phone, // 통화 관련 dangerous 권한 그룹
        ].request();

    final phoneGranted = statuses[Permission.phone]?.isGranted ?? false;

    if (!phoneGranted) {
      // 영구 거부 시 설정 이동 유도
      if (await Permission.phone.isPermanentlyDenied) {
        final go = await _askOpenSettings(
          '전화/통화기록 권한이 영구적으로 거부되었습니다.\n설정에서 권한을 허용해주세요.',
        );
        if (go == true) await openAppSettings();
      }
      return false;
    }
    return true;
  }

  /// 연락처 권한 (Android/iOS 공통) — flutter_contacts가 제공하는 API 사용
  static Future<bool> requestContacts() async {
    final granted = await FlutterContacts.requestPermission(readonly: true);
    if (!granted) {
      final go = await _askOpenSettings('연락처 권한이 거부되었습니다.\n설정에서 권한을 허용해주세요.');
      if (go == true) await openAppSettings();
    }
    return granted;
  }

  /// 권한 설명 다이얼로그
  static Future<bool?> _askOpenSettings(String message) {
    return Get.dialog<bool>(
      AlertDialog(
        title: const Text('권한 필요'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('설정 열기'),
          ),
        ],
      ),
      barrierDismissible: true,
    );
  }
}
