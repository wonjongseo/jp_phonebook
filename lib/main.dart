import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
// main.dart
import 'package:jg_phonebook/lookup_entry.dart' as lookup;

// 🔴 네이티브에서 찾을 이름은 main.dart 안의 이 함수입니다.
@pragma('vm:entry-point')
Future<void> lookupMain() async {
  await lookup.lookupMainImpl(); // 실제 구현을 호출
}

const _ch = MethodChannel('native_overlay_channel');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  final box = await Hive.openBox('labels');
  await box.put('08012345678', '회사A · 영업1팀');
  await box.put('07055608528', '나야 · 종서');
  await box.put('0312345678', '고객센터');
  await box.put('0120123456', '협력사 B 담당자');
  await box.put('+818012345678', '회사A · 영업1팀');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SPPM Phonebook (Native Overlay)',
      theme: ThemeData(useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _requestAll() async {
    if (!Platform.isAndroid) return;
    await _ch.invokeMethod('requestRuntimePermissions');
    await _ch.invokeMethod('requestOverlayPermission');
    await _ch.invokeMethod('requestBatteryException'); // 사용자 동의 필요
  }

  Future<void> _testOverlay() async {
    await _ch.invokeMethod('startDummyOverlay', {'number': '01012345678'});
  }

  Future<void> _closeOverlay() async {
    await _ch.invokeMethod('stopOverlay');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Native Overlay Demo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            FilledButton(
              onPressed: _requestAll,
              child: const Text('권한/예외 요청(앱 화면에서만)'),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: _testOverlay,
              child: const Text('더미 번호로 오버레이 테스트'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _closeOverlay,
              child: const Text('오버레이 닫기'),
            ),
            const SizedBox(height: 24),
            const Text(
              '※ 실제 착신 시에는 PhoneStateReceiver → CallIncomingService가 자동으로 실행됩니다.\n'
              '※ 수신 타이밍에는 절대 권한 팝업/Activity를 띄우지 마세요.',
            ),
          ],
        ),
      ),
    );
  }
}
