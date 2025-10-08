import 'dart:convert';
import 'package:flutter/services.dart';

const MethodChannel _ch = MethodChannel('call_directory_channel');

class CallDirectoryEntry {
  final String number; // 원본 입력("+81...", "03...", "090..." 등)
  final String label; // "고객A", "회사대표" 등
  const CallDirectoryEntry({required this.number, required this.label});

  Map<String, String> toJson() => {'number': number, 'label': label};
}

/// 네이티브(iOS App)로 목록 전달(저장은 네이티브가 App Group에 수행)
Future<void> updateIdentifiers(List<CallDirectoryEntry> entries) async {
  final payload = {'entries': entries.map((e) => e.toJson()).toList()};
  await _ch.invokeMethod('updateIdentifiers', jsonEncode(payload));
}

/// 익스텐션 리로드 (다음 착신부터 반영)
Future<bool> reloadExtension() async {
  final ok = await _ch.invokeMethod('reloadExtension');
  return ok == true;
}

/// 편의: 업데이트 후 즉시 리로드
Future<bool> updateAndReload(List<CallDirectoryEntry> entries) async {
  print('entries : ${entries}');

  await updateIdentifiers(entries);
  return await reloadExtension();
}
