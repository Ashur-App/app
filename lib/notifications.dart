import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class NotificationService {
  static StreamSubscription<DatabaseEvent>? _rtdbNotifSub;
  static Future<void> initialize(BuildContext context) async {
    await Firebase.initializeApp();
    if (!kIsWeb && Platform.isAndroid) {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }
    if (!kIsWeb) {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      final InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);
      await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    }
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _showNotification(
          message.notification!.title ?? '',
          message.notification!.body ?? '',
        );
      }
    });
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await _saveTokenToDatabase();
    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      await _saveTokenToDatabase(token: token);
    });
    _listenForRealtimeNotifications();
  }

  static void _listenForRealtimeNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final ref = FirebaseDatabase.instance.ref('notifications/${user.uid}');
    _rtdbNotifSub?.cancel();
    _rtdbNotifSub = ref.limitToLast(1).onChildAdded.listen((event) async {
      final n = event.snapshot.value;
      final notifId = event.snapshot.key;
      if (n is Map && n['title'] != null && n['body'] != null) {
        if (n['read'] == true) return;
        await _showNotification(n['title'], n['body']);
        if (notifId != null) {
          await FirebaseDatabase.instance.ref('notifications/${user.uid}/$notifId').update({'read': true});
        }
      }
    });
  }

  static Future<void> _showNotification(String title, String body) async {
    if (kIsWeb) return;
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload: null,
    );
  }

  static Future<void> _saveTokenToDatabase({String? token}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final fcmToken = token ?? await FirebaseMessaging.instance.getToken(
      vapidKey: kIsWeb ? 'YOUR_WEB_PUSH_CERTIFICATE_KEY_PAIR' : null,
    );
    if (fcmToken != null) {
      await FirebaseDatabase.instance
          .ref('users/${user.uid}/fcmToken')
          .set(fcmToken);
    }
  }
} 