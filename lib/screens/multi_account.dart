import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class MultiAccountScreen extends StatefulWidget {
  const MultiAccountScreen({super.key});

  @override
  State<MultiAccountScreen> createState() => _MultiAccountScreenState();
}

class _MultiAccountScreenState extends State<MultiAccountScreen> with RouteAware {
  List<Map<String, String>> _accounts = [];
  bool _loading = true;
  String? _currentUid;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('account_'));
    final accounts = <Map<String, String>>[];
    for (final key in keys) {
      final value = prefs.getString(key);
      if (value != null) {
        final parts = value.split('||');
        if (parts.length == 3) {
          accounts.add({
            'uid': parts[0],
            'email': parts[1],
            'refreshToken': parts[2],
          });
        }
      }
    }
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      _accounts = accounts;
      _currentUid = user?.uid;
      _loading = false;
    });
  }

  Future<void> _addAccount() async {
    print('[DEBUG] _addAccount called');
    final result = await Navigator.pushNamed(context, '/login', arguments: {'multiAccount': true});
    print('[DEBUG] _addAccount result: $result');
    if (result is User) {
      final refreshToken = await result.getIdToken();
      final plain = '${result.uid}||${result.email}||$refreshToken';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('account_${result.uid}', plain);
      await _loadAccounts();
      print('[DEBUG] Account added for uid: ${result.uid}');
    } else {
      print('[DEBUG] Add account result is not User: result=$result');
    }
  }

  Future<void> _switchAccount(Map<String, String> account) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تسجيل الدخول'),
        content: Text('لأسباب أمنية، يرجى إعادة تسجيل الدخول لهذا الحساب.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
              final result = await Navigator.pushNamed(
                context,
                '/login',
                arguments: {'email': account['email'], 'multiAccount': true},
              );
              if (result is User) {
                final refreshToken = await result.getIdToken();
                final plain = '${result.uid}||${result.email}||$refreshToken';
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('account_${result.uid}', plain);
                await _loadAccounts();
              }
            },
            child: Text('تسجيل الدخول'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeAccount(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('account_$uid');
    await _loadAccounts();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
      appBar: AppBar(
        title: Text('إدارة الحسابات'),
        backgroundColor: colorScheme.surface,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: _accounts.length,
                    itemBuilder: (context, i) {
                      final acc = _accounts[i];
                      final isCurrent = acc['uid'] == _currentUid;
                      return FutureBuilder<DataSnapshot>(
                        future: FirebaseDatabase.instance.ref('users/${acc['uid']}').get(),
                        builder: (context, snapshot) {
                          String username = acc['email'] ?? '';
                          String? pfp;
                          if (snapshot.hasData && snapshot.data!.value != null) {
                            try {
                              final data = Map<String, dynamic>.from(snapshot.data!.value as Map);
                              print('[DEBUG] User data for UID ${acc['uid']}: $data');
                              username = data['username'] != null && data['username'].toString().isNotEmpty
                                ? '@${data['username']}'
                                : username;
                              pfp = data['pic'] as String?;
                            } catch (e) {
                              print('[DEBUG] Error parsing user data for UID ${acc['uid']}: $e');
                            }
                          } else {
                            print('[DEBUG] No user data for UID ${acc['uid']}');
                          }
                          return Card(
                            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundImage: pfp != null && pfp.isNotEmpty
                                    ? NetworkImage(pfp)
                                    : AssetImage('images/ashur.png') as ImageProvider,
                                radius: 22,
                                backgroundColor: colorScheme.primary.withOpacity(0.1),
                              ),
                              title: Text(username.isNotEmpty ? username : acc['email'] ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: isCurrent ? Text('الحساب الحالي', style: TextStyle(color: colorScheme.primary)) : null,
                              onTap: isCurrent ? null : () => _switchAccount(acc),
                              trailing: IconButton(
                                icon: Icon(Icons.delete, color: colorScheme.error),
                                onPressed: () => _removeAccount(acc['uid']!),
                                tooltip: 'حذف',
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.add),
                    label: Text('إضافة حساب جديد'),
                    onPressed: () {
                      print('[DEBUG] Add Account button pressed');
                      _addAccount();
                    },
                  ),
                ),
              ],
              ),
            ),
    );
  }
} 