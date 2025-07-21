import 'dart:convert';
import 'package:ashur/secrets.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:math';
import 'package:crypto/crypto.dart';
class BotMakerScreen extends StatefulWidget {
  const BotMakerScreen({super.key});
  @override
  State<BotMakerScreen> createState() => _BotMakerScreenState();
}

class _BotMakerScreenState extends State<BotMakerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  final _picController = TextEditingController();
  final _bioController = TextEditingController();
  final _webhookController = TextEditingController();
  bool _isLoading = false;
  String? _botToken;
  String? _botSecret;
  String? _botUid;
  String? _webhookUrl;
  List<Map<String, dynamic>> _bots = [];
  bool _loadingBots = false;
  bool _showForm = false;
  String _sortBy = 'default';

  @override
  void initState() {
    super.initState();
    _loadBots();
  }

  Future<void> _loadBots() async {
    setState(() { _loadingBots = true; });
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snap = await FirebaseDatabase.instance.ref('bots').orderByChild('owner').equalTo(user.uid).get();
    List<Map<String, dynamic>> bots = [];
    if (snap.exists && snap.value != null) {
      final data = Map<String, dynamic>.from(snap.value as Map);
      data.forEach((key, value) {
        final bot = Map<String, dynamic>.from(value as Map);
        bot['uid'] = key;
        bots.add(bot);
      });
    }
    setState(() { _bots = bots; _loadingBots = false; });
  }

  Future<void> _deleteBot(String botUid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذا البوت؟ لا يمكن التراجع.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await FirebaseDatabase.instance.ref('bots/$botUid').remove();
      await FirebaseDatabase.instance.ref('users/$botUid').remove();
      await _loadBots();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف البوت')));
    }
  }

  Future<void> _regenerateSecret(String botUid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد التجديد'),
        content: const Text('هل تريد تجديد سر البوت؟ السر القديم سيتوقف فوراً.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('تجديد')), 
        ],
      ),
    );
    if (confirmed == true) {
      final newSecret = _generateSecret();
      final newHash = sha256.convert(utf8.encode(newSecret)).toString();
      await FirebaseDatabase.instance.ref('bots/$botUid/secretHash').set(newHash);
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('سر جديد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('احتفظ بهذا السر الجديد. لن يظهر مرة أخرى.'),
              const SizedBox(height: 16),
              SelectableText(newSecret),
              const SizedBox(height: 8),
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: newSecret));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ السر')));
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
    }
  }

  String _generateSecret() {
    final rand = List.generate(32, (i) => Random.secure().nextInt(256));
    return base64Url.encode(rand).substring(0, 32);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('يجب تسجيل الدخول');
      final idToken = await user.getIdToken();
      final res = await http.post(
        Uri.parse(ashurBotApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'username': _usernameController.text.trim(),
          'name': _nameController.text.trim(),
          'pic': _picController.text.trim(),
          'bio': _bioController.text.trim(),
          'webhookUrl': _webhookController.text.trim(),
        }),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode != 200) throw Exception(data['error'] ?? 'خطأ غير معروف');
      setState(() {
        _botToken = data['botToken'];
        _botSecret = data['botSecret'];
        _botUid = data['botUid'];
        _webhookUrl = data['webhookUrl'];
      });
      await _loadBots();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text('تم إنشاء البوت'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('احتفظ بهذه المعلومات في مكان آمن. لن تظهر مرة أخرى.'),
                const SizedBox(height: 16),
                SelectableText('Token: $_botToken'),
                const SizedBox(height: 8),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    if (_botToken != null) {
                      Clipboard.setData(ClipboardData(text: _botToken!));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ التوكن')));
                    }
                  },
                ),
                const SizedBox(height: 8),
                SelectableText('Secret: $_botSecret'),
                const SizedBox(height: 8),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    if (_botSecret != null) {
                      Clipboard.setData(ClipboardData(text: _botSecret!));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ السر')));
                    }
                  },
                ),
                if (_webhookUrl != null && _webhookUrl!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SelectableText('Webhook: $_webhookUrl'),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('حسناً'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final size = MediaQuery.of(context).size;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('إنشاء بوت جديد'),
          backgroundColor: colorScheme.surface,
          elevation: 0,
        ),
        backgroundColor: colorScheme.surface,
        floatingActionButton: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
          child: FloatingActionButton(
            key: ValueKey(_showForm),
            onPressed: () => setState(() => _showForm = !_showForm),
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: _showForm
                  ? Icon(Icons.close, key: const ValueKey('close'), size: 28)
                  : Icon(Icons.add, key: const ValueKey('add'), size: 28),
            ),
          ),
        ),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            child: _showForm
                ? _buildCreateForm(context, colorScheme, textTheme)
                : _buildBotsList(context, colorScheme, textTheme),
          ),
        ),
      ),
    );
  }

  Widget _buildBotsList(BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    List<Map<String, dynamic>> sortedBots = List<Map<String, dynamic>>.from(_bots);
    if (_sortBy == 'name') {
      sortedBots.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
    } else if (_sortBy == 'date_newest') {
      sortedBots.sort((a, b) => (b['createdAt'] ?? '').toString().compareTo((a['createdAt'] ?? '').toString()));
    } else if (_sortBy == 'date_oldest') {
      sortedBots.sort((a, b) => (a['createdAt'] ?? '').toString().compareTo((b['createdAt'] ?? '').toString()));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FadeTransition(
            opacity: AlwaysStoppedAnimation(1.0),
            child: Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colorScheme.primary.withOpacity(0.18)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: colorScheme.primary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'يمكنك إنشاء بوتات خاصة بك لإدارة محادثات أو مجموعات أو حتى بناء خدمات ذكية. اضغط على زر + لإضافة بوت جديد!',
                      style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.8)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!_loadingBots && _bots.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Text('ترتيب حسب:', style: textTheme.bodyMedium),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _sortBy,
                    onChanged: (val) => setState(() => _sortBy = val ?? 'default'),
                    items: const [
                      DropdownMenuItem(value: 'default', child: Text('الافتراضي')),
                      DropdownMenuItem(value: 'name', child: Text('الاسم')),
                      DropdownMenuItem(value: 'date_newest', child: Text('الأحدث')),
                      DropdownMenuItem(value: 'date_oldest', child: Text('الأقدم')),
                    ],
                  ),
                ],
              ),
            ),
          if (_loadingBots)
            const Center(child: CircularProgressIndicator()),
         if (!_loadingBots && sortedBots.isNotEmpty)
           Column(
             crossAxisAlignment: CrossAxisAlignment.stretch,
             children: [
               Text('بوتاتي', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
               const SizedBox(height: 12),
               ListView.separated(
                 shrinkWrap: true,
                 physics: const NeverScrollableScrollPhysics(),
                 itemCount: sortedBots.length,
                 separatorBuilder: (_, __) => const SizedBox(height: 14),
                 itemBuilder: (context, i) {
                   final bot = sortedBots[i];
                   return AnimatedContainer(
                     duration: const Duration(milliseconds: 300),
                     curve: Curves.easeInOut,
                     width: double.infinity,
                     decoration: BoxDecoration(
                       color: colorScheme.surfaceContainerHighest,
                       borderRadius: BorderRadius.circular(18),
                       border: Border.all(color: colorScheme.outline.withOpacity(0.13)),
                       boxShadow: [
                         BoxShadow(
                           color: colorScheme.shadow.withOpacity(0.07),
                           blurRadius: 8,
                           offset: const Offset(0, 2),
                         ),
                       ],
                     ),
                     child: Padding(
                       padding: const EdgeInsets.all(14),
                       child: Row(
                         children: [
                           bot['pic'] != null && bot['pic'].toString().isNotEmpty
                             ? CircleAvatar(backgroundImage: NetworkImage(bot['pic']), radius: 28)
                             : const CircleAvatar(child: Icon(Icons.smart_toy)),
                           const SizedBox(width: 14),
                           Expanded(
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               mainAxisAlignment: MainAxisAlignment.center,
                               children: [
                                 Text(bot['name'] ?? '', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                                 Text('ID: ${bot['uid']}', style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withOpacity(0.6))),
                                 if (bot['bio'] != null && bot['bio'].toString().isNotEmpty)
                                   Text('نبذة: ${bot['bio']}', style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withOpacity(0.7))),
                                 if (bot['webhookUrl'] != null && bot['webhookUrl'].toString().isNotEmpty)
                                   Text('Webhook: ${bot['webhookUrl']}', style: textTheme.bodySmall?.copyWith(color: colorScheme.primary)),
                                 if (bot['createdAt'] != null && bot['createdAt'].toString().isNotEmpty)
                                   Text('تاريخ الإنشاء: ${_formatDate(bot['createdAt'])}', style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withOpacity(0.6))),
                               ],
                             ),
                           ),
                           Column(
                             mainAxisAlignment: MainAxisAlignment.center,
                             children: [
                               IconButton(
                                 icon: const Icon(Icons.vpn_key),
                                 tooltip: 'تجديد السر',
                                 onPressed: () => _regenerateSecret(bot['uid']),
                               ),
                               IconButton(
                                 icon: const Icon(Icons.delete, color: Colors.red),
                                 tooltip: 'حذف',
                                 onPressed: () => _deleteBot(bot['uid']),
                               ),
                             ],
                           ),
                         ],
                       ),
                     ),
                   );
                 },
               ),
               const SizedBox(height: 32),
             ],
           ),
          if (!_loadingBots && _bots.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Center(
                child: Text('لا يوجد لديك بوتات بعد. اضغط + لإضافة أول بوت!', style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface.withOpacity(0.7))),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCreateForm(BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colorScheme.outline.withOpacity(0.18)),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: _picController.text.trim().isNotEmpty && Uri.tryParse(_picController.text.trim()) != null
                    ? CircleAvatar(
                        key: ValueKey(_picController.text.trim()),
                        backgroundImage: NetworkImage(_picController.text.trim()),
                        radius: 36,
                      )
                    : CircleAvatar(
                        key: const ValueKey('default'),
                        radius: 36,
                        backgroundColor: colorScheme.primary.withOpacity(0.13),
                        child: Icon(Icons.smart_toy, color: colorScheme.primary, size: 32),
                      ),
                ),
              ),
              const SizedBox(height: 18),
              _buildMaterial3Field(
                controller: _usernameController,
                label: 'اسم المستخدم (بدون مسافات)',
                icon: Icons.alternate_email,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'مطلوب';
                  if (v.trim().length < 3) return 'يجب أن يكون 3 أحرف على الأقل';
                  if (v.contains(' ')) return 'بدون مسافات';
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              _buildMaterial3Field(
                controller: _nameController,
                label: 'اسم العرض',
                icon: Icons.badge_outlined,
                validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              _buildMaterial3Field(
                controller: _picController,
                label: 'رابط صورة البوت (اختياري)',
                icon: Icons.image_outlined,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              _buildMaterial3Field(
                controller: _bioController,
                label: 'نبذة عن البوت (اختياري)',
                icon: Icons.edit_note,
                textInputAction: TextInputAction.next,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              _buildMaterial3Field(
                controller: _webhookController,
                label: 'رابط Webhook (اختياري)',
                icon: Icons.link,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final url = Uri.tryParse(v.trim());
                  if (url == null || !(url.isScheme('http') || url.isScheme('https'))) return 'رابط غير صالح';
                  return null;
                },
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 32),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary,
                      colorScheme.primary.withOpacity(0.8),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _isLoading ? null : _submit,
                    child: Center(
                      child: _isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colorScheme.onPrimary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'جاري الإنشاء...',
                                  style: textTheme.labelLarge?.copyWith(
                                    color: colorScheme.onPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_circle_outline, color: colorScheme.onPrimary, size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  'إنشاء البوت',
                                  style: textTheme.labelLarge?.copyWith(
                                    color: colorScheme.onPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMaterial3Field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputAction? textInputAction,
    int maxLines = 1,
    void Function(String)? onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        enabled: !_isLoading,
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: colorScheme.onSurface.withOpacity(0.7),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(20),
          prefixIcon: Icon(
            icon,
            color: colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 16,
        ),
        validator: validator,
        textInputAction: textInputAction,
        maxLines: maxLines,
        onChanged: onChanged,
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final dt = date is int ? DateTime.fromMillisecondsSinceEpoch(date) : DateTime.tryParse(date.toString());
      if (dt == null) return date.toString();
      return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return date.toString();
    }
  } 
} 