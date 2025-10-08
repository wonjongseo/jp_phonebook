import 'package:flutter/material.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    _callNumber() async {
      const number = '0123456789'; //enter your number here
      bool? res = await FlutterPhoneDirectCaller.callNumber(number);
      print('res : ${res}');
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              InkWell(
                onTap: () {
                  _callNumber();
                },
                child: Text('contacts'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
