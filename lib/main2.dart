// lib/main.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
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
  await updateIdentifiers(entries);
  return await reloadExtension();
}

class CallDirectoryDemoPage extends StatefulWidget {
  const CallDirectoryDemoPage({super.key});

  @override
  State<CallDirectoryDemoPage> createState() => _CallDirectoryDemoPageState();
}

class _CallDirectoryDemoPageState extends State<CallDirectoryDemoPage> {
  final _numberController = TextEditingController(text: "07055608528");
  final _labelController = TextEditingController(text: '나야');
  final List<CallDirectoryEntry> _entries = [];

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  void test() async {
    const _ch = MethodChannel('call_directory_channel');
    print(
      await _ch.invokeMethod('debugContainer'),
    ); // containerURL=Optional(file://...)
    print(await _ch.invokeMethod('debugAppGroup')); // read=ping
  }

  @override
  void dispose() {
    _numberController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  void _addEntry() {
    final number = _numberController.text.trim();
    final label = _labelController.text.trim();
    if (number.isEmpty || label.isEmpty) {
      _toast(context, '번호와 라벨을 모두 입력하세요.');
      return;
    }
    setState(() {
      _entries.add(CallDirectoryEntry(number: number, label: label));
      _numberController.clear();
      _labelController.clear();
    });
  }

  Future<void> _saveAndReload() async {
    if (!Platform.isIOS) {
      _toast(context, 'iOS에서만 동작합니다.');
      return;
    }
    if (_entries.isEmpty) {
      _toast(context, '등록할 항목이 없습니다.');
      return;
    }
    try {
      _toast(context, '저장 중…');
      final ok = await updateAndReload(_entries);
      if (ok) {
        _toast(context, '저장 + 리로드 성공! (다음 착신부터 반영)');
      } else {
        _toast(context, '리로드 호출 실패 (Xcode 로그 확인)');
      }
    } catch (e) {
      _toast(context, '오류: $e');
    }
  }

  // 샘플 데이터 한 번에 채우기
  void _fillSamples() {
    setState(() {
      _entries
        ..clear()
        ..addAll([
          CallDirectoryEntry(number: '+819012345678', label: '고객A'),
          CallDirectoryEntry(number: '0361234567', label: '회사대표'),
          CallDirectoryEntry(number: '09011112222', label: '영업부'),
        ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Call Directory 등록/리로드')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _numberController,
                    decoration: const InputDecoration(
                      labelText: '전화번호 (+81..., 03..., 090...)',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _labelController,
                    decoration: const InputDecoration(
                      labelText: '라벨 (예: 고객A, 회사대표)',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(onPressed: _addEntry, child: const Text('추가')),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                FilledButton.tonal(
                  onPressed: _fillSamples,
                  child: const Text('샘플 채우기'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _saveAndReload,
                  child: const Text('저장 + 리로드'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child:
                  _entries.isEmpty
                      ? const Center(child: Text('등록 대기 중…'))
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
                              onPressed:
                                  () => setState(() => _entries.removeAt(i)),
                            ),
                          );
                        },
                      ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                test();
              },
              child: Text('Text'),
            ),
            const Text(
              '⚠️ iOS에서 “설정 > 전화 > 전화 차단 및 발신자 확인”에서 '
              'PhoneBookCallDirectory 확장을 켜야 라벨이 표시됩니다.\n'
              '리로드 후 “다음 착신부터” 반영됩니다.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}


//dart run change_app_package_name:main com.wonjongseo.jp-phonebook --android