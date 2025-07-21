import 'package:ashur/screens/foryou.dart';
import 'package:ashur/screens/login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class Auth extends StatelessWidget {
  const Auth({super.key});


  Future<void> requestStoragePermission() async {
  var status = await Permission.storage.status;

  if (!status.isGranted) {
    await Permission.storage.request();
  }
}

  @override
  Widget build(BuildContext context) {
    try {
      requestStoragePermission();
    } catch (e) {}
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: ((context, snapshot) {
          if (snapshot.hasData) {
            return foryouscreen();
          } else {
            return LoginScreen();
          }
        }),
      ),
    );
  }
}
