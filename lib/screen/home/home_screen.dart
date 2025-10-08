import 'package:flutter/material.dart';
import 'package:get/state_manager.dart';
import 'package:jg_phonebook/controller/call_log_controller.dart';
import 'package:jg_phonebook/screen/call_log_tabbed_screen.dart';
import 'package:jg_phonebook/screen/contacts_screen.dart';
import 'package:jg_phonebook/screen/keypad/keypad_screen.dart';

class TapController extends GetxController {
  List<Widget> _bodys = [ContactsScreen(), CallLogTabbedPage(), KeypadScreen()];

  Widget get body => _bodys[selectedIndex.value];
  final selectedIndex = 0.obs;

  void onDestinationSelected(int index) {
    selectedIndex.value = index;
  }
}

class HomeScreen extends GetView<TapController> {
  static String name = '/';
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        appBar: AppBar(),
        body: controller.body,
        bottomNavigationBar: NavigationBar(
          onDestinationSelected: controller.onDestinationSelected,
          indicatorColor: Colors.amber,
          selectedIndex: controller.selectedIndex.value,
          destinations: const <Widget>[
            NavigationDestination(
              selectedIcon: Icon(Icons.home),
              icon: Icon(Icons.home_outlined),
              label: '電話帳',
            ),
            NavigationDestination(icon: Icon(Icons.map), label: '発着信履歴'),
            NavigationDestination(icon: Icon(Icons.keyboard), label: 'キーバット'),
          ],
        ),
      ),
    );
  }
}
