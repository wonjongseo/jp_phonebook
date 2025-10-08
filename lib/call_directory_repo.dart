// import 'dart:convert';
// import 'package:flutter/services.dart';

// class CallDirectoryEntry {
//   final String number; // "+81..." 또는 "03..." 등
//   final String label; // "고객A", "회사대표" 등
//   CallDirectoryEntry({required this.number, required this.label});

//   Map<String, String> toJson() => {'number': number, 'label': label};
// }

// class CallDirectoryRepo {
//   static const _appGroupId = 'group.com.wonjongseo.jpphonebook';
//   static const _key = 'cd_identifiers_json';
//   static const _channel = MethodChannel('call_directory_channel');

//   static Future<void> debugCheck() async {
//     final status = await _channel.invokeMethod('getExtensionStatus');
//     // status: "enabled" | "disabled" | "unknown" | "error: ..."
//     print('CallDirectory status: $status');
//   }

//   /// App Group(UserDefaults suite)에 JSON 저장
//   static Future<void> saveEntries(List<CallDirectoryEntry> entries) async {
//     await SharedPreferenceAppGroup.setAppGroup(_appGroupId);
//     final jsonStr = jsonEncode(entries.map((e) => e.toJson()).toList());
//     await SharedPreferenceAppGroup.setString(_key, jsonStr);
//   }

//   /// iOS 네이티브에서 Call Directory Extension 리로드 지시
//   static Future<bool> reloadExtension() async {
//     final res = await _channel.invokeMethod('reloadExtension');
//     return res == true;
//   }

//   /// 편의 함수: 저장 + 리로드
//   static Future<bool> saveAndReload(List<CallDirectoryEntry> entries) async {
//     await saveEntries(entries);
//     return await reloadExtension();
//   }
// }
