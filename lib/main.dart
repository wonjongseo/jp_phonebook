import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/route_manager.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:jg_phonebook/controller/call_log_controller.dart';
import 'package:jg_phonebook/controller/local_contact_controller.dart';
import 'package:jg_phonebook/look_up_main.dart' as lookUp;
import 'package:jg_phonebook/repository/label_repo.dart';
import 'package:jg_phonebook/services/navite/native_service.dart';
import 'package:jg_phonebook/screen/home/home_screen.dart';

//Android Headless Entrypoint (着信時Nativeが実施）
@pragma('vm:entry-point')
Future<void> lookupMain() async {
  lookUp.lookupMainImpl();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  await LabelRepo.init();
  await LabelRepo.seedIfEmpty();

  await NativeService.instance.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Phonebook (Hive + NativeService)',
      theme: ThemeData(useMaterial3: true),
      getPages: AppPages.getPages,
      initialRoute: HomeScreen.name,
      initialBinding: InitialBinding(),
    );
  }
}

class AppPages {
  static List<GetPage<dynamic>> get getPages {
    return [GetPage(name: HomeScreen.name, page: () => HomeScreen())];
  }
}

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(TapController(), permanent: true);
    Get.lazyPut(() => LocalContactController(), fenix: true);
    Get.lazyPut(() => CallLogController(Get.find()), fenix: true);
  }
}
