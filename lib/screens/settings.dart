import 'package:ashur/user_badges.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ashur/screens/app_devs.dart';
import 'package:ashur/screens/custom_themes.dart';
import 'multi_account.dart';
import 'package:ashur/screens/bot_maker.dart';
import 'package:ashur/screens/onboarding.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with TickerProviderStateMixin {
  bool _isPrivate = false;
  bool _loading = true;
  ThemeMode _themeMode = ThemeMode.system;
  double _fontSize = 1.0;
  List<String> _blockedUsers = [];
  String? _uid;
  Map<String, dynamic>? _userData;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  String _appVersion = '';
  String _themeModeString = 'system';

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: Duration(milliseconds: 700));
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);
    _loadSettings();
    _loadAppVersion();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _uid = user.uid;
      final snap = await FirebaseDatabase.instance.ref('users/${user.uid}').get();
      if (snap.exists && snap.value != null) {
        _userData = Map<String, dynamic>.from(snap.value as Map);
        _isPrivate = _userData?['private'] == true;
        _blockedUsers = List<String>.from(_userData?['blockedUsers'] ?? []);
      }
    }
    final theme = prefs.getString('themeMode') ?? 'system';
    final font = prefs.getDouble('fontSize') ?? 1.0;
    if (!mounted) return;
    setState(() {
      _themeMode = theme == 'dark' ? ThemeMode.dark : theme == 'light' ? ThemeMode.light : theme == 'custom' ? ThemeMode.system : ThemeMode.system;
      _themeModeString = theme;
      _fontSize = font;
      _loading = false;
    });
    _fadeController.forward();
  }

  Future<void> _saveTheme(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode);
    if (!mounted) return;
    setState(() {
      _themeMode = mode == 'dark' ? ThemeMode.dark : mode == 'light' ? ThemeMode.light : mode == 'custom' ? ThemeMode.system : ThemeMode.system;
      _themeModeString = mode;
    });
  }

  Future<void> _saveFontSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontSize', size);
    if (!mounted) return;
    setState(() { _fontSize = size; });
  }

  Future<void> _togglePrivate(bool value) async {
    if (_uid == null) return;
    await FirebaseDatabase.instance.ref('users/$_uid').update({'private': value});
    setState(() { _isPrivate = value; });
  }

  Future<void> _unblockUser(String uid) async {
    if (_uid == null) return;
    _blockedUsers.remove(uid);
    await FirebaseDatabase.instance.ref('users/$_uid').update({'blockedUsers': _blockedUsers});
    setState(() {});
  }

  Future<Map<String, dynamic>?> _getUserData(String userId) async {
    try {
      DatabaseEvent event = await FirebaseDatabase.instance.ref('users').child(userId).once();
      if (event.snapshot.exists) {
        Map<String, dynamic> userData = Map<String, dynamic>.from(event.snapshot.value as Map<Object?, Object?>);
        return userData;
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _appVersion = info.version;
    });
  }

  void _showThemePicker() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('اختر المظهر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              SizedBox(height: 16),
              RadioListTile<String>(
                value: 'system',
                groupValue: _themeModeString,
                onChanged: (v) { _saveTheme('system'); Navigator.pop(context); },
                title: Text('النظام'),
              ),
              RadioListTile<String>(
                value: 'light',
                groupValue: _themeModeString,
                onChanged: (v) { _saveTheme('light'); Navigator.pop(context); },
                title: Text('فاتح'),
              ),
              RadioListTile<String>(
                value: 'dark',
                groupValue: _themeModeString,
                onChanged: (v) { _saveTheme('dark'); Navigator.pop(context); },
                title: Text('داكن'),
              ),
              RadioListTile<String>(
                value: 'custom',
                groupValue: _themeModeString,
                onChanged: (v) { _saveTheme('custom'); Navigator.pop(context); },
                title: Text('مخصص'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFontSizePicker() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        double localFontSize = _fontSize;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('حجم الخط', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  SizedBox(height: 16),
                  Slider(
                    value: localFontSize,
                    min: 0.8,
                    max: 1.5,
                    divisions: 7,
                    label: '${(localFontSize * 100).toInt()}%',
                    onChanged: (v) {
                      setModalState(() { localFontSize = v; });
                    },
                    onChangeEnd: (v) {
                      _saveFontSize(v);
                      setState(() { _fontSize = v; });
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showFeedbackDialog() {
    showDialog(
      context: context,
      builder: (context) {
        TextEditingController feedbackController = TextEditingController();
        bool isSending = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('إرسال ملاحظات'),
              content: TextField(
                controller: feedbackController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'اكتب ملاحظاتك أو اقتراحاتك هنا...'
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: isSending
                      ? null
                      : () async {
                          if (feedbackController.text.trim().isEmpty) return;
                          setState(() => isSending = true);
                          final user = FirebaseAuth.instance.currentUser;
                          final feedbackRef = FirebaseDatabase.instance.ref('feedback').push();
                          await feedbackRef.set({
                            'uid': user?.uid,
                            'feedback': feedbackController.text.trim(),
                            'timestamp': DateTime.now().toUtc().toIso8601String(),
                          });
                          setState(() => isSending = false);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('تم إرسال الملاحظات بنجاح!')),
                          );
                        },
                  child: isSending ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text('إرسال'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (_loading) return Scaffold(body: Center(child: CircularProgressIndicator()));
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('الإعدادات', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: colorScheme.surface,
          elevation: 0,
        ),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                margin: EdgeInsets.only(bottom: 28),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset('images/ashur.png', width: 56, height: 56),
                      SizedBox(height: 16),
                      Text('تطبيق آشور', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: colorScheme.primary)),
                      SizedBox(height: 8),
                      Text('الإصدار: ${_appVersion.isNotEmpty ? _appVersion : '...'}', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7), fontSize: 14)),
                      SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AppDevsScreen()),
                  );
                },
                child: Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerHighest,
                  margin: EdgeInsets.only(bottom: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: ListTile(
                    leading: Icon(Icons.info_outline, color: colorScheme.primary),
                    title: Text('عن المطورين', style: TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Icon(Icons.chevron_left),
                  ),
                ),
              ),
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHighest,
                margin: EdgeInsets.only(bottom: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: ListTile(
                  leading: Icon(Icons.feedback_outlined, color: colorScheme.primary),
                  title: Text('إرسال ملاحظات', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: _showFeedbackDialog,
                  trailing: Icon(Icons.chevron_left),
                ),
              ),
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHighest,
                margin: EdgeInsets.only(bottom: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: ListTile(
                  leading: Icon(Icons.switch_account, color: colorScheme.primary),
                  title: Text('تبديل الحساب', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => MultiAccountScreen()),
                    );
                  },
                  trailing: Icon(Icons.chevron_left),
                ),
              ),
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHighest,
                margin: EdgeInsets.only(bottom: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.color_lens, color: colorScheme.primary),
                      title: Text('المظهر', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(_themeModeString == 'system' ? 'النظام' : _themeModeString == 'light' ? 'فاتح' : _themeModeString == 'dark' ? 'داكن' : 'مخصص'),
                      onTap: _showThemePicker,
                      trailing: Icon(Icons.chevron_left),
                    ),
                    if (_themeModeString == 'custom')
                      ListTile(
                        leading: Icon(Icons.palette_outlined),
                        title: Text('المظاهر المخصصة'),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => CustomThemesScreen()),
                          );
                        },
                      ),
                    Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.text_fields, color: colorScheme.primary),
                      title: Text('حجم الخط', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${(_fontSize * 100).toInt()}%'),
                      onTap: _showFontSizePicker,
                      trailing: Icon(Icons.chevron_left),
                    ),
                  ],
                ),
              ),
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHighest,
                margin: EdgeInsets.only(bottom: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.lock, color: colorScheme.primary),
                      title: Text('حساب خاص', style: TextStyle(fontWeight: FontWeight.bold)),
                      trailing: Switch(
                        value: _isPrivate,
                        onChanged: _togglePrivate,
                        activeColor: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHighest,
                margin: EdgeInsets.only(bottom: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.block, color: colorScheme.primary),
                      title: Text('المستخدمون المحظورون', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: _blockedUsers.isEmpty
                        ? Text('لا يوجد مستخدمون محظورون')
                        : null,
                    ),
                    if (_blockedUsers.isNotEmpty)
                      ..._blockedUsers.map((uid) => FutureBuilder<Map<String, dynamic>?>(
                        future: _getUserData(uid),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return ListTile(
                              leading: CircleAvatar(child: Icon(Icons.person)),
                              title: Text(uid),
                              trailing: TextButton(
                                onPressed: () => _unblockUser(uid),
                                child: Text('إلغاء الحظر'),
                              ),
                            );
                          }
                          final user = snapshot.data!;
                          final profilePic = user['pic'] ?? '';
                          final username = user['username'] ?? uid;
                          final name = user['name'] ?? '';
                          final profileTheme = user['profileTheme'] != null && user['profileTheme'].toString().isNotEmpty ? Color(int.tryParse(user['profileTheme'].toString()) ?? 0) : colorScheme.primary;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: profilePic.isNotEmpty ? NetworkImage(profilePic) : AssetImage('images/ashur.png') as ImageProvider,
                              radius: 20,
                              backgroundColor: colorScheme.primary.withOpacity(0.1),
                            ),
                            title: Row(
                              children: [
                                Text('@$username', style: TextStyle(fontWeight: FontWeight.bold, color: profileTheme)),
                                SizedBox(width: 6),
                                UserBadges(userData: user, iconSize: 16),
                              ],
                            ),
                            subtitle: name.isNotEmpty ? Text(name, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)) : null,
                            trailing: ElevatedButton.icon(
                              onPressed: () => _unblockUser(uid),
                              icon: Icon(Icons.lock_open, size: 18),
                              label: Text('إلغاء الحظر', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                elevation: 0,
                              ),
                            ),
                          );
                        },
                      )),
                  ],
                ),
              ),
              ListTile(
                leading: Icon(Icons.smart_toy, color: colorScheme.primary),
                title: Text('إنشاء بوت', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const BotMakerScreen()),
                  );
                },
                trailing: Icon(Icons.chevron_left),
              ),
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHighest,
                margin: EdgeInsets.only(bottom: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: ListTile(
                  leading: Icon(Icons.school, color: colorScheme.primary),
                  title: Text('إعادة مشاهدة المقدمة', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('onboardingComplete', false);
                    if (!mounted) return;
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => OnboardingScreen(
                          onFinish: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (context) => SettingsScreen()),
                            );
                          },
                        ),
                      ),
                    );
                  },
                  trailing: Icon(Icons.chevron_left),
                ),
              ),
              Card(
                elevation: 0,
                color: colorScheme.error.withOpacity(0.08),
                margin: EdgeInsets.only(bottom: 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.logout, color: colorScheme.error),
                          SizedBox(width: 12),
                          Text('خطر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: colorScheme.error)),
                        ],
                      ),
                      SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: Icon(Icons.logout, color: colorScheme.onError),
                        label: Text('تسجيل الخروج', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onError)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.error,
                          foregroundColor: colorScheme.onError,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          final first = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('تأكيد تسجيل الخروج'),
                              content: Text('هل أنت متأكد أنك تريد تسجيل الخروج؟'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: Text('إلغاء'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: Text('تأكيد'),
                                ),
                              ],
                            ),
                          );
                          if (first == true) {
                            final second = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text('تأكيد نهائي'),
                                content: Text('هل أنت متأكد 100% أنك تريد تسجيل الخروج؟'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: Text('إلغاء'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: Text('تسجيل الخروج'),
                                  ),
                                ],
                              ),
                            );
                            if (second == true) {
                              await FirebaseAuth.instance.signOut();
                              if (mounted) {
                                Navigator.of(context).popUntil((route) => route.isFirst);
                              }
                            }
                          }
                        },
                      ),
                      SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: Icon(Icons.delete_forever, color: colorScheme.onError),
                        label: Text('حذف جميع الحسابات المحفوظة', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onError)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.error,
                          foregroundColor: colorScheme.onError,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('تأكيد الحذف'),
                              content: Text('هل أنت متأكد أنك تريد حذف جميع الحسابات المحفوظة؟ لا يمكن التراجع عن هذا الإجراء.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: Text('إلغاء'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: Text('حذف', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            final prefs = await SharedPreferences.getInstance();
                            final accountKeys = prefs.getKeys().where((k) => k.startsWith('account_')).toList();
                            for (final k in accountKeys) {
                              await prefs.remove(k);
                            }
                            await prefs.remove('multi_account_aes_key');
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('تم حذف جميع الحسابات المحفوظة بنجاح'), backgroundColor: colorScheme.error),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 