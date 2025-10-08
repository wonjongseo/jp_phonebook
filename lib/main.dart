import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

const MethodChannel kIncomingBridge = MethodChannel('incoming_overlay_channel');

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OverlayApp());
}

@pragma('vm:entry-point')
void overlayDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();

  kIncomingBridge.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'showOverlay':
        final number = (call.arguments as String?) ?? 'Unknown';

        if (!await FlutterOverlayWindow.isPermissionGranted()) return;
        final active = await FlutterOverlayWindow.isActive();
        if (!active) {
          await FlutterOverlayWindow.showOverlay(
            overlayTitle: 'Incoming Call',
            overlayContent: 'Overlay is running',
            // width: WindowSize.matchParent,
            // height: 200,
            height: 800,
            width: 700,
            alignment: OverlayAlignment.center,
            flag: OverlayFlag.defaultFlag,
            enableDrag: true,
          );
          await Future.delayed(const Duration(milliseconds: 250));
        }
        await FlutterOverlayWindow.shareData(number);
        break;

      case 'closeOverlay':
        await FlutterOverlayWindow.closeOverlay();
        break;
    }
  });
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SPPM Phonebook',
      theme: ThemeData(useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  void _requestPermissions() async {
    await _requestBasePermissions();
    _openOverlaySettings();
  }

  Future<void> _requestBasePermissions() async {
    if (!Platform.isAndroid) return;
    final phone = await Permission.phone.request(); // READ_PHONE_STATE
    setState(() {
      print('phone: ${phone}');
    });
  }

  Future<void> _openOverlaySettings() async {
    if (!await FlutterOverlayWindow.isPermissionGranted()) {
      await FlutterOverlayWindow.requestPermission();
    }
  }

  Future<void> _testOverlay() async {
    if (!await FlutterOverlayWindow.isPermissionGranted()) {
      await FlutterOverlayWindow.requestPermission();
      await Future.delayed(const Duration(milliseconds: 300));
    }
    if (!await FlutterOverlayWindow.isPermissionGranted()) {
      debugPrint('overlay perm still denied');
      return;
    }

    if (await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.closeOverlay();
      await Future.delayed(const Duration(milliseconds: 200));
    }

    await FlutterOverlayWindow.showOverlay(
      overlayTitle: 'Incoming Call',
      overlayContent: 'Showing number overlay',
      height: 400,
      width: 700,
      enableDrag: true,
      alignment: OverlayAlignment.center,
      flag: OverlayFlag.defaultFlag,
    );

    await Future.delayed(const Duration(milliseconds: 200));
    await FlutterOverlayWindow.shareData('01012345678');

    debugPrint('isActive: ${await FlutterOverlayWindow.isActive()}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SPPM Phonebook (Flutter Overlay)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            FilledButton(onPressed: _testOverlay, child: const Text('Test')),
          ],
        ),
      ),
    );
  }
}

class OverlayApp extends StatefulWidget {
  const OverlayApp({super.key});
  @override
  State<OverlayApp> createState() => _OverlayAppState();
}

class _OverlayAppState extends State<OverlayApp> {
  String _number = 'Unknown';

  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data is String) setState(() => _number = data);
      debugPrint('overlay received: $data');
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.only(top: 32, left: 8, right: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.redAccent, width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.phone_in_talk, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '電話が来ました',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _number,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.close),
                onPressed: () async => FlutterOverlayWindow.closeOverlay(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// // lib/main.dart
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:jg_phonebook/call_directory_bridge.dart';
// import 'call_directory_repo.dart';

// void main() {
//   WidgetsFlutterBinding.ensureInitialized();
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Call Directory Demo',
//       theme: ThemeData(useMaterial3: true),
//       home: const CallDirectoryDemoPage(),
//     );
//   }
// }

// class CallDirectoryDemoPage extends StatefulWidget {
//   const CallDirectoryDemoPage({super.key});

//   @override
//   State<CallDirectoryDemoPage> createState() => _CallDirectoryDemoPageState();
// }

// class _CallDirectoryDemoPageState extends State<CallDirectoryDemoPage> {
//   final _numberController = TextEditingController(text: "07055608528");
//   final _labelController = TextEditingController(text: '나야');
//   final List<CallDirectoryEntry> _entries = [];

//   @override
//   void initState() {
//     // TODO: implement initState
//     super.initState();
//   }

//   void test() async {
//     const _ch = MethodChannel('call_directory_channel');
//     print(
//       await _ch.invokeMethod('debugContainer'),
//     ); // containerURL=Optional(file://...)
//     print(await _ch.invokeMethod('debugAppGroup')); // read=ping
//   }

//   @override
//   void dispose() {
//     _numberController.dispose();
//     _labelController.dispose();
//     super.dispose();
//   }

//   void _addEntry() {
//     final number = _numberController.text.trim();
//     final label = _labelController.text.trim();
//     if (number.isEmpty || label.isEmpty) {
//       _toast(context, '번호와 라벨을 모두 입력하세요.');
//       return;
//     }
//     setState(() {
//       _entries.add(CallDirectoryEntry(number: number, label: label));
//       _numberController.clear();
//       _labelController.clear();
//     });
//   }

//   Future<void> _saveAndReload() async {
//     if (!Platform.isIOS) {
//       _toast(context, 'iOS에서만 동작합니다.');
//       return;
//     }
//     if (_entries.isEmpty) {
//       _toast(context, '등록할 항목이 없습니다.');
//       return;
//     }
//     try {
//       _toast(context, '저장 중…');
//       final ok = await updateAndReload(_entries);
//       if (ok) {
//         _toast(context, '저장 + 리로드 성공! (다음 착신부터 반영)');
//       } else {
//         _toast(context, '리로드 호출 실패 (Xcode 로그 확인)');
//       }
//     } catch (e) {
//       _toast(context, '오류: $e');
//     }
//   }

//   // 샘플 데이터 한 번에 채우기
//   void _fillSamples() {
//     setState(() {
//       _entries
//         ..clear()
//         ..addAll([
//           CallDirectoryEntry(number: '+819012345678', label: '고객A'),
//           CallDirectoryEntry(number: '0361234567', label: '회사대표'),
//           CallDirectoryEntry(number: '09011112222', label: '영업부'),
//         ]);
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Call Directory 등록/리로드')),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [
//             Row(
//               children: [
//                 Expanded(
//                   child: TextField(
//                     controller: _numberController,
//                     decoration: const InputDecoration(
//                       labelText: '전화번호 (+81..., 03..., 090...)',
//                     ),
//                     keyboardType: TextInputType.phone,
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: TextField(
//                     controller: _labelController,
//                     decoration: const InputDecoration(
//                       labelText: '라벨 (예: 고객A, 회사대표)',
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 FilledButton(onPressed: _addEntry, child: const Text('추가')),
//               ],
//             ),
//             const SizedBox(height: 16),
//             Row(
//               children: [
//                 FilledButton.tonal(
//                   onPressed: _fillSamples,
//                   child: const Text('샘플 채우기'),
//                 ),
//                 const SizedBox(width: 12),
//                 FilledButton(
//                   onPressed: _saveAndReload,
//                   child: const Text('저장 + 리로드'),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 16),
//             Expanded(
//               child:
//                   _entries.isEmpty
//                       ? const Center(child: Text('등록 대기 중…'))
//                       : ListView.separated(
//                         itemCount: _entries.length,
//                         separatorBuilder: (_, __) => const Divider(height: 1),
//                         itemBuilder: (context, i) {
//                           final e = _entries[i];
//                           return ListTile(
//                             title: Text(e.label),
//                             subtitle: Text(e.number),
//                             trailing: IconButton(
//                               icon: const Icon(Icons.delete_outline),
//                               onPressed:
//                                   () => setState(() => _entries.removeAt(i)),
//                             ),
//                           );
//                         },
//                       ),
//             ),
//             const SizedBox(height: 8),
//             TextButton(
//               onPressed: () {
//                 test();
//               },
//               child: Text('Text'),
//             ),
//             const Text(
//               '⚠️ iOS에서 “설정 > 전화 > 전화 차단 및 발신자 확인”에서 '
//               'PhoneBookCallDirectory 확장을 켜야 라벨이 표시됩니다.\n'
//               '리로드 후 “다음 착신부터” 반영됩니다.',
//               textAlign: TextAlign.center,
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _toast(BuildContext context, String msg) {
//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
//   }
// }


// //dart run change_app_package_name:main com.wonjongseo.jp-phonebook --android