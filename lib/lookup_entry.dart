// lib/lookup_entry.dart
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

const _channel = MethodChannel('incoming_lookup');

@pragma('vm:entry-point') // 반드시 필요: 커스텀 엔트리포인트 노출
Future<void> lookupMainImpl() async {
  print('a');
  WidgetsFlutterBinding.ensureInitialized();

  // Hive 초기화 (headless 엔진에서도 경로 확보)
  final dir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(dir.path);
  // 예: 'labels' 박스에 { "08012345678": "회사A(영업)", "0312345678": "고객센터" } 형태 저장한다고 가정
  final box = await Hive.openBox<dynamic>('labels');

  _channel.setMethodCallHandler((call) async {
    if (call.method == 'lookupLabel') {
      final args = (call.arguments as Map?) ?? const {};
      final raw = (args['number'] as String? ?? '').trim();

      // 번호 정규화(일본 기준 예시) : +81 -> 0, 하이픈/공백 제거
      String normalize(String s) {
        var n = s.replaceAll(RegExp(r'[\s\-]'), '');
        if (n.startsWith('+81')) n = '0${n.substring(3)}';
        return n;
      }

      final key = normalize(raw);

      // 1) 정확히 일치
      var label = box.get(key) as String?;
      // 2) 못 찾으면 끝 7~8자리 후방 일치 등 느슨한 매칭(옵션)
      if (label == null) {
        final tail = key.length >= 8 ? key.substring(key.length - 8) : key;
        for (final k in box.keys.map((e) => e.toString())) {
          if (k.endsWith(tail)) {
            label = box.get(k) as String?;
            break;
          }
        }
      }
      print('label : ${label}');

      return label; // null이면 네이티브에서 "등록 없음" 등 처리
    }
    return null;
  });
  try {
    await _channel.invokeMethod('ready');
  } catch (_) {
    // 네이티브에서 ready를 안 받도록 해도 무관하므로 무시
  }
}
