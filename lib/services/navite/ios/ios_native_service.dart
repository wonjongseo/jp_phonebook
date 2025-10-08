import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:jg_phonebook/core/constants.dart';
import 'package:jg_phonebook/main.dart';
import 'package:jg_phonebook/repository/label_repo.dart';
import 'package:jg_phonebook/services/navite/native_service.dart';

/// 간단 디바운서 (iOS 리로드 남발 방지)
class Debouncer {
  final Duration duration;
  Timer? _t;
  Debouncer(this.duration);
  void run(FutureOr<void> Function() action) {
    _t?.cancel();
    _t = Timer(duration, () {
      action();
    });
  }
}

/// ===============================
/// iOS 구현
class IosNativeService extends NativeService {
  IosNativeService();

  final _debouncer = Debouncer(const Duration(milliseconds: 800));

  @override
  Future<void> init() async {
    // iOS는 확장 활성화를 팝업으로 강제할 수 없음. (선택) 네이티브에서 상태 안내 트리거
    try {
      await kIosDirectoryChannel.invokeMethod('ensureEnabledIfPossible');
    } catch (_) {
      /* no-op */
    }
  }

  @override
  Future<String> getStatus() async {
    if (!Platform.isIOS) return 'enabled';
    final status = await kIosDirectoryChannel.invokeMethod(
      'getExtensionStatus',
    );
    return (status as String?) ?? 'unknown';
  }

  @override
  Future<void> ensureEnabledOrPrompt(BuildContext context) async {
    if (!Platform.isIOS) return;
    final status = await getStatus();
    if (status == 'enabled') return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('설정 필요'),
            content: const Text(
              '전화 식별 라벨을 표시하려면 iOS 설정에서 확장을 켜야 합니다.\n\n'
              '경로: 설정 > 전화 > 전화 차단 및 발신자 확인 > "PhoneBookCallDirectory" 켜기',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('나중에'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('설정 열기'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await kIosDirectoryChannel.invokeMethod('openAppSettings');
    }
  }

  @override
  Future<void> syncFromHive() async {
    final entries = LabelRepo.all(); // List<CallDirectoryEntry>
    final payload = {'entries': entries.map((e) => e.toJson()).toList()};
    await kIosDirectoryChannel.invokeMethod(
      'updateIdentifiers',
      jsonEncode(payload),
    );
  }

  @override
  Future<bool> reload() async {
    final ok = await kIosDirectoryChannel.invokeMethod('reloadExtension');
    return ok == true;
  }

  @override
  Future<void> onLabelsChanged() async {
    // 추가/삭제가 여러 번 빠르게 일어나도 마지막 한 번만 리로드
    _debouncer.run(() async {
      await syncFromHive();
      await reload(); // iOS 정책상 "다음 착신부터" 반영
    });
  }
}
