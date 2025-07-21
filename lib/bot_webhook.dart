import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> triggerBotWebhooks({
  required String target,
  required String senderUid,
  required String message,
  required bool isGroup,
  required String action,
}) async {
  print('[BotWebhook] triggerBotWebhooks called with target: $target, senderUid: $senderUid, message: $message, isGroup: $isGroup, action: $action');
  List<String> botUids = [];
  if (isGroup) {
    final groupSnap = await FirebaseDatabase.instance.ref('groups/$target').get();
    print('[BotWebhook] Group snapshot exists: ${groupSnap.exists}, value: ${groupSnap.value}');
    if (groupSnap.exists && groupSnap.value != null) {
      final groupData = Map<String, dynamic>.from(groupSnap.value as Map);
      final members = groupData['members'];
      if (members is List) {
        botUids = List<String>.from(members);
      } else if (members is Map) {
        botUids = members.keys.map((e) => e.toString()).toList();
      }
      print('[BotWebhook] Group botUids: $botUids');
    }
    for (final botUid in botUids) {
      final botSnap = await FirebaseDatabase.instance.ref('bots/$botUid').get();
      print('[BotWebhook] Checking botUid: $botUid, exists: ${botSnap.exists}');
      if (botSnap.exists && botSnap.value != null) {
        final botData = Map<String, dynamic>.from(botSnap.value as Map);
        final webhookUrl = botData['webhookUrl'];
        print('[BotWebhook] Found bot $botUid with webhookUrl: $webhookUrl');
        if (webhookUrl != null && webhookUrl.toString().isNotEmpty) {
          try {
            final response = await http.post(
              Uri.parse(webhookUrl),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'target': target,
                'user': senderUid,
                'message': message,
                'action': action,
                'isGroup': isGroup,
              }),
            );
            print('[BotWebhook] Webhook POST to $webhookUrl responded with status: ${response.statusCode}, body: ${response.body}');
          } catch (e) {
            print("[BotWebhook] Error sending webhook to $webhookUrl: $e");
          }
        } else {
          print('[BotWebhook] Bot $botUid has no webhookUrl set.');
        }
      } else {
        print('[BotWebhook] No bot found for UID: $botUid');
      }
    }
  } else {
    final parts = target.split('-');
    botUids = parts;
    print('[BotWebhook] DM botUids: $botUids');
    for (final botUid in botUids) {
      final botSnap = await FirebaseDatabase.instance.ref('bots/$botUid').get();
      print('[BotWebhook] Checking botUid: $botUid, exists: ${botSnap.exists}');
      if (botSnap.exists && botSnap.value != null) {
        final botData = Map<String, dynamic>.from(botSnap.value as Map);
        final webhookUrl = botData['webhookUrl'];
        print('[BotWebhook] Found bot $botUid with webhookUrl: $webhookUrl');
        if (webhookUrl != null && webhookUrl.toString().isNotEmpty) {
          final otherUid = botUids.firstWhere((uid) => uid != botUid, orElse: () => senderUid);
          try {
            final response = await http.post(
              Uri.parse(webhookUrl),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'target': otherUid,
                'user': senderUid,
                'message': message,
                'action': action,
                'isGroup': isGroup,
              }),
            );
            print('[BotWebhook] Webhook POST to $webhookUrl responded with status: ${response.statusCode}, body: ${response.body}');
          } catch (e) {
            print("[BotWebhook] Error sending webhook to $webhookUrl: $e");
          }
        } else {
          print('[BotWebhook] Bot $botUid has no webhookUrl set.');
        }
      } else {
        print('[BotWebhook] No bot found for UID: $botUid');
      }
    }
  }
} 