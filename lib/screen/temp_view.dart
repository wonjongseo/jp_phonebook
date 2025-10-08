import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:jg_phonebook/repository/label_repo.dart';
import 'package:jg_phonebook/services/navite/ios/entity/call_directory_entry.dart';
import 'package:jg_phonebook/services/navite/native_service.dart';
// ⛔️ 네이티브 서비스 파일을 따로 쓰지 않고 이 파일 내에서 구현합니다.

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
  }

  void _refresh() => setState(() {
    _entries = LabelRepo.all();
  });

  Future<void> _add() async {
    final n = _numberCtrl.text.trim();
    final l = _labelCtrl.text.trim();
    if (n.isEmpty || l.isEmpty) return _toast('번호/라벨 모두 입력');
    await LabelRepo.put(n, l);
    await _native.onLabelsChanged(); // ← 추가 직후 즉시 반영(iOS 자동 동기화/리로드)
    _numberCtrl.clear();
    _labelCtrl.clear();
    _refresh();
  }

  Future<void> _remove(String number) async {
    await LabelRepo.remove(number);
    await _native.onLabelsChanged(); // ← 삭제 직후 즉시 반영(iOS 자동 동기화/리로드)
    _refresh();
  }

  Future<void> _iosSyncAndReload() async {
    // 수동 버튼(디버깅용)도 유지
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
