import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'chatscreen.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});
  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  String? _uid;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _uid = user.uid;
    final snap = await FirebaseDatabase.instance.ref('notifications/$_uid').get();
    if (snap.exists && snap.value != null) {
      final data = Map<String, dynamic>.from(snap.value as Map);
      _notifications = data.entries.map((e) {
        final n = Map<String, dynamic>.from(e.value);
        n['id'] = e.key;
        return n;
      }).toList();
      _notifications.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
      _unreadCount = _notifications.where((n) => n['read'] != true).length;
    }
    setState(() { _loading = false; });
  }

  Future<void> _markAsRead(String id) async {
    if (_uid == null) return;
    await FirebaseDatabase.instance.ref('notifications/$_uid/$id').update({'read': true});
    setState(() { _notifications.firstWhere((n) => n['id'] == id)['read'] = true; _unreadCount--; });
  }

  void _handleNotificationTap(Map<String, dynamic> n) async {
    await _markAsRead(n['id']);
    if (n['type'] == 'message' && n['data'] != null && n['data']['chatId'] != null) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatScreen(
          targetUserEmail: n['data']['targetUserEmail'],
          currentUserEmail: _uid!,
        ),
      ));
    } else if (n['type'] == 'post' && n['data'] != null && n['data']['postId'] != null) {
      // TODO
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('الإشعارات'),
            if (_unreadCount > 0)
              Container(
                margin: EdgeInsets.only(right: 8),
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$_unreadCount', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
      body: AnimatedSwitcher(
        duration: Duration(milliseconds: 300),
        child: ListView.builder(
          key: ValueKey(_notifications.length),
          itemCount: _notifications.length,
          itemBuilder: (context, i) {
            final n = _notifications[i];
            final isUnread = n['read'] != true;
            return AnimatedContainer(
              duration: Duration(milliseconds: 300),
              margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isUnread ? Colors.amber.withOpacity(0.15) : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isUnread ? Colors.amber : Colors.transparent, width: 1.5),
                boxShadow: [
                  if (isUnread)
                    BoxShadow(color: Colors.amber.withOpacity(0.1), blurRadius: 8, offset: Offset(0, 2)),
                ],
              ),
              child: ListTile(
                onTap: () => _handleNotificationTap(n),
                title: Text(n['title'] ?? '', style: TextStyle(fontWeight: isUnread ? FontWeight.bold : FontWeight.normal)),
                subtitle: n['body'] != null ? Text(n['body']) : null,
                trailing: isUnread ? Icon(Icons.circle, color: Colors.amber, size: 14) : null,
              ),
            );
          },
        ),
      ),
    );
  }
} 