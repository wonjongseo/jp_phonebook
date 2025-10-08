// lib/feature/calllog/controller/call_log_controller.dart
import 'dart:async';
import 'dart:io';
import 'package:get/get.dart';
import 'package:call_log/call_log.dart';
import 'package:jg_phonebook/controller/local_contact_controller.dart';
import 'package:jg_phonebook/services/permission_service.dart';
import 'package:phone_state/phone_state.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/contact.dart';

class CallLogController extends GetxController {
  CallLogController(this._contacts);
  final LocalContactController _contacts;

  final logs = <CallLogEntry>[].obs;
  final inCommingLogs = <CallLogEntry>[].obs;
  final outCommingLogs = <CallLogEntry>[].obs;
  final isLoading = false.obs;

  StreamSubscription<PhoneState>? _phoneSub;
  int? _lastTs;

  @override
  void onInit() {
    super.onInit();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (!Platform.isAndroid) return;

    final ok = await PermissionService.requestPhoneAndCallLog();

    if (!ok) return;

    await refreshLogs(full: true);
    _bindPhoneState();
  }

  void _bindPhoneState() {
    _phoneSub?.cancel();
    _phoneSub = PhoneState.stream.listen((s) async {
      final status = s.status;
      if (status == PhoneStateStatus.CALL_ENDED) {
        await Future.delayed(const Duration(seconds: 2));
        await refreshLogs(full: false);
      }
    });
  }

  Future<void> onAppResumed() async {
    if (!Platform.isAndroid) return;
    await refreshLogs(full: false);
  }

  Future<void> refreshLogs({required bool full}) async {
    if (!Platform.isAndroid) return;
    try {
      isLoading.value = true;

      Iterable<CallLogEntry> entries;
      if (full || _lastTs == null) {
        entries = await CallLog.query();
      } else {
        entries = await CallLog.query(dateFrom: _lastTs);
      }

      final fresh =
          entries.toList()
            ..sort((a, b) => (b.timestamp ?? 0).compareTo(a.timestamp ?? 0));

      if (fresh.isNotEmpty) {
        _lastTs = fresh.first.timestamp ?? _lastTs;
      }

      if (full) {
        logs.assignAll(fresh);
      } else {
        final known = logs.map(_keyOf).toSet();
        for (final e in fresh) {
          if (!known.contains(_keyOf(e))) {
            logs.insert(0, e);
          }
        }
      }

      for (var log in logs) {
        if (log.callType == CallType.outgoing) {
          outCommingLogs.add(log);
        } else {
          inCommingLogs.add(log);
        }
      }
    } catch (e) {
      Get.snackbar('오류', '통화기록을 읽을 수 없습니다. 권한을 확인해주세요.');
    } finally {
      isLoading.value = false;
    }
  }

  String _keyOf(CallLogEntry e) =>
      '${e.timestamp ?? 0}|${e.number ?? ''}|${e.duration ?? 0}|${e.callType}';

  String typeLabel(CallType? t) {
    switch (t) {
      case CallType.incoming:
        return '수신';
      case CallType.outgoing:
        return '발신';
      case CallType.missed:
        return '부재중';
      case CallType.blocked:
        return '차단';
      case CallType.rejected:
        return '거절';
      default:
        return '기타';
    }
  }

  /// UI에서 쓸: 로그 번호 → 연락처 조회
  ContactModel? contactOf(callLogEntry) {
    final raw = callLogEntry.number ?? callLogEntry.formattedNumber;
    return _contacts.lookup(raw);
  }

  @override
  void onClose() {
    _phoneSub?.cancel();
    super.onClose();
  }
}
