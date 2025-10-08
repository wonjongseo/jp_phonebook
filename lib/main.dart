import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// ===============================
/// 채널/상수
/// ===============================
const kAndroidOverlayChannel = MethodChannel(
  'native_overlay_channel',
); // Android 권한/오버레이
const kIosDirectoryChannel = MethodChannel(
  'call_directory_channel',
); // iOS 콜 디렉터리
const kAndroidLookupChannelName = 'incoming_lookup'; // Android headless 조회 채널

const _labelsBoxName = 'labels'; // 번호→라벨 저장 Hive 박스명

/// ===============================
/// 공통 모델/유틸
/// ===============================
class CallDirectoryEntry {
  final String number; // "+81...", "03...", "090..." 등
  final String label; // "고객A", "회사대표" 등
  const CallDirectoryEntry({required this.number, required this.label});
  Map<String, String> toJson() => {'number': number, 'label': label};
}

/// 일본 번호 정규화 예시: +81 -> 0, 하이픈/공백 제거
String normalizeNumber(String raw) {
  var n = raw.trim().replaceAll(RegExp(r'[\s\-]'), '');
  if (n.startsWith('+81')) n = '0${n.substring(3)}';
  return n;
}

/// ===============================
/// Hive Repository (단일 소스)
/// ===============================
class LabelRepo {
  static Future<void> init() async {
    if (!Hive.isBoxOpen(_labelsBoxName)) {
      await Hive.openBox<String>(_labelsBoxName);
    }
  }

  static Box<String> get _box => Hive.box<String>(_labelsBoxName);

  static Future<void> seedIfEmpty() async {
    if (_box.isEmpty) {
      await _box.putAll({
        normalizeNumber('08012345678'): '회사A · 영업1팀',
        normalizeNumber('07055608528'): '나야 · 종서',
        normalizeNumber('0312345678'): '고객센터',
        normalizeNumber('0120123456'): '협력사 B 담당자',
      });
    }
  }

  static Future<void> put(String number, String label) async {
    await _box.put(normalizeNumber(number), label);
  }

  static Future<void> remove(String number) async {
    await _box.delete(normalizeNumber(number));
  }

  static List<CallDirectoryEntry> all() {
    return _box.keys.map((k) {
      final key = k.toString();
      final v = _box.get(key) ?? '';
      return CallDirectoryEntry(number: key, label: v);
    }).toList();
  }

  /// 안드로이드 헤드리스 조회에서 사용: 정규화→정확 일치→뒤 8자리 느슨 매칭
  static String? lookupLabel(String rawNumber) {
    final key = normalizeNumber(rawNumber);
    final hit = _box.get(key);
    if (hit != null && hit.isNotEmpty) return hit;

    final tail = key.length >= 8 ? key.substring(key.length - 8) : key;
    for (final k in _box.keys) {
      final s = k.toString();
      if (s.endsWith(tail)) {
        final v = _box.get(s);
        if (v != null && v.isNotEmpty) return v;
      }
    }
    return null;
  }
}

/// ===============================
/// NativeService 추상 클래스 + 플랫폼 구현
/// ===============================
abstract class NativeService {
  /// 앱 시작 시 자동 호출: 플랫폼별 필수 권한/상태 체크 & 요청
  Future<void> init() async {}

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

  Future<void> getStatus() async => _unsupported('syncFromHive');
  static Future<void> ensureEnabledOrPrompt(BuildContext context) async =>
      _unsupported('syncFromHive');

  static T _unsupported<T>(String fn) {
    throw UnsupportedError(
      'NativeService.$fn is not supported on this platform',
    );
  }

  static final NativeService instance =
      Platform.isIOS ? IosNativeService._() : AosNativeService._();
}

/// iOS 구현
class IosNativeService extends NativeService {
  IosNativeService._();

  Future<String> getStatus() async {
    if (!Platform.isIOS) return 'enabled'; // iOS 전용
    final status = await kIosDirectoryChannel.invokeMethod(
      'getExtensionStatus',
    );
    return (status as String?) ?? 'unknown';
  }

  /// 비활성 상태라면 경고 다이얼로그를 띄우고, [설정 열기]를 누르면 앱 설정으로 이동
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
      await kIosDirectoryChannel.invokeMethod('openAppSettings'); // 앱 설정 화면 오픈
    }
  }

  @override
  Future<void> init() async {
    // iOS는 Call Directory 활성화를 시스템 팝업으로 “요청”할 수 없음.
    // 네이티브가 상태 점검/안내 배너를 띄우도록 만들었다면(선택),
    // 아래 메서드 이름에 맞춰 호출해두면 됨. (미구현이어도 try-catch로 무시)
    try {
      await kIosDirectoryChannel.invokeMethod('ensureEnabledIfPossible');
    } catch (_) {
      /* no-op */
    }
  }

  @override
  Future<void> syncFromHive() async {
    final entries = LabelRepo.all();
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
}

/// Android 구현
class AosNativeService extends NativeService {
  AosNativeService._();

  @override
  Future<void> init() async {
    // 앱이 포그라운드 상태일 때 자동 요청:
    // - requestRuntimePermissions: READ_PHONE_STATE/NUMBERS/CALL_LOG(선택)/POST_NOTIFICATIONS(13+)
    // - requestOverlayPermission: SYSTEM_ALERT_WINDOW
    // - requestBatteryException: Doze 예외(핵심 기능에 필요할 때만)
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
}

/// ===============================
/// Android Headless Entrypoint (수신 시 네이티브가 실행)
/// - 반드시 main.dart 안에 있어야 함
/// - 네이티브 LookupEngineProvider 에서 "lookupMain" 호출
/// ===============================
@pragma('vm:entry-point')
Future<void> lookupMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await LabelRepo.init();

  const ch = MethodChannel(kAndroidLookupChannelName);

  ch.setMethodCallHandler((call) async {
    if (call.method == 'lookupLabel') {
      final raw = ((call.arguments as Map?)?['number'] as String?) ?? '';
      return LabelRepo.lookupLabel(raw);
    }
    return null;
  });

  try {
    await ch.invokeMethod('ready');
  } catch (_) {}
}

/// ===============================
/// 앱 엔트리 + 샘플 UI
/// ===============================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await LabelRepo.init();
  await LabelRepo.seedIfEmpty();

  // 🔥 앱 시작 시 플랫폼별 필수 권한/상태 자동 요청
  await NativeService.instance.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Phonebook (Hive + NativeService)',
      theme: ThemeData(useMaterial3: true),
      home: const PhonebookHomePage(),
    );
  }
}

class PhonebookHomePage extends StatefulWidget {
  const PhonebookHomePage({super.key});
  @override
  State<PhonebookHomePage> createState() => _PhonebookHomePageState();
}

class _PhonebookHomePageState extends State<PhonebookHomePage> {
  final _numberCtrl = TextEditingController(text: '07055608528');
  final _labelCtrl = TextEditingController(text: '나야');
  List<CallDirectoryEntry> _entries = [];

  NativeService get _native => NativeService.instance;

  @override
  void initState() {
    super.initState();
    _refresh();

    // 앱 재개 시(포그라운드 복귀) 권한 재확인/보강이 필요하면 여기에 훅 추가 가능
    // WidgetsBinding.instance.addObserver(...);
  }

  void _refresh() => setState(() => _entries = LabelRepo.all());

  Future<void> _add() async {
    final n = _numberCtrl.text.trim();
    final l = _labelCtrl.text.trim();
    if (n.isEmpty || l.isEmpty) return _toast('번호/라벨 모두 입력');
    await LabelRepo.put(n, l);
    _numberCtrl.clear();
    _labelCtrl.clear();
    _refresh();
  }

  Future<void> _remove(String number) async {
    await LabelRepo.remove(number);
    _refresh();
  }

  Future<void> _iosSyncAndReload() async {
    try {
      await _native.syncFromHive();
      final ok = await _native.reload();
      _toast(ok ? 'iOS 동기화+리로드 완료 (다음 착신부터)' : '리로드 실패');
    } catch (e) {
      _toast('iOS 오류: $e');
    }
  }

  Future<void> _androidStartOverlay() async {
    final n =
        _numberCtrl.text.trim().isEmpty
            ? '01012345678'
            : _numberCtrl.text.trim();
    try {
      await _native.startOverlay(n);
    } catch (e) {
      _toast('Android 오류: $e');
    }
  }

  Future<void> _androidStopOverlay() => _native.stopOverlay();

  @override
  Widget build(BuildContext context) {
    final isIOS = Platform.isIOS;
    final isAndroid = Platform.isAndroid;

    return Scaffold(
      appBar: AppBar(title: const Text('Phonebook (Hive + NativeService)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 입력
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _numberCtrl,
                    decoration: const InputDecoration(
                      labelText: '전화번호 (+81..., 03..., 090...)',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _labelCtrl,
                    decoration: const InputDecoration(
                      labelText: '라벨 (예: 고객A, 회사대표)',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(onPressed: _add, child: const Text('추가')),
              ],
            ),
            const SizedBox(height: 16),

            // 플랫폼별 버튼
            Row(
              children: [
                if (isIOS)
                  FilledButton(
                    onPressed: _iosSyncAndReload,
                    child: const Text('iOS: 콜 디렉터리 동기화+리로드'),
                  ),
                if (isAndroid) ...[
                  FilledButton(
                    onPressed: _androidStartOverlay,
                    child: const Text('Android: 오버레이 테스트'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _androidStopOverlay,
                    child: const Text('오버레이 닫기'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // 리스트
            Expanded(
              child:
                  _entries.isEmpty
                      ? const Center(child: Text('등록 항목 없음'))
                      : ListView.separated(
                        itemCount: _entries.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final e = _entries[i];
                          return ListTile(
                            title: Text(e.label),
                            subtitle: Text(e.number),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _remove(e.number),
                            ),
                          );
                        },
                      ),
            ),
            if (isIOS)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '⚠️ iOS: 설정 > 전화 > 전화 차단 및 발신자 확인에서 확장을 켜야 라벨이 표시됩니다.',
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}
