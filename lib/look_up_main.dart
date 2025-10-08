import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:jg_phonebook/core/constants.dart';
import 'package:jg_phonebook/repository/label_repo.dart';

@pragma('vm:entry-point')
Future<void> lookupMainImpl() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  const ch = MethodChannel(kAndroidLookupChannelName);

  ch.setMethodCallHandler((call) async {
    if (call.method == 'lookupLabel') {
      // 🔑 핵심: 매 호출마다 최신 상태 확보
      if (Hive.isBoxOpen(labelsBoxName)) {
        await Hive.box<String>(labelsBoxName).close();
      }
      await Hive.openBox<String>(labelsBoxName);

      final raw = ((call.arguments as Map?)?['number'] as String?) ?? '';
      return LabelRepo.lookupLabel(raw);
    }
    return null;
  });

  try {
    await ch.invokeMethod('ready');
  } catch (_) {}
}
