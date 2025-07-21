

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(begin: Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<bool> _isUsernameTaken(String username) async {
    final ref = FirebaseDatabase.instance.ref('users');
    final snapshot = await ref.get();
    if (snapshot.exists && snapshot.value != null) {
      final users = Map<String, dynamic>.from(snapshot.value as Map);
      for (final entry in users.entries) {
        final userData = Map<String, dynamic>.from(entry.value as Map);
        if ((userData['username'] as String?)?.toLowerCase() == username.toLowerCase()) {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final username = _usernameController.text.trim();
      if (await _isUsernameTaken(username)) {
        HapticFeedback.heavyImpact();
        setState(() { _isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('اسم المستخدم مستخدم بالفعل، يرجى اختيار اسم آخر'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }

      HapticFeedback.lightImpact();
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (userCredential.user != null) {
        await FirebaseDatabase.instance.ref('users/${userCredential.user!.uid}').set({
          'username': _usernameController.text.trim(),
          'email': _emailController.text.trim(),
          'id': userCredential.user!.uid,
          'created_at': DateTime.now().toUtc().toString(),
          'verify': false,
          'mod': false,
          'contributor': false,
          'team': false,
          'achievements': [],
          'private': false,
          'blockedUsers': [],
          'dailyChallengeCompleted': false,
          'weeklyChallengeCompleted': false,
        });

        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إنشاء الحساب بنجاح'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context, FirebaseAuth.instance.currentUser);
      }
    } on FirebaseAuthException catch (e) {
      HapticFeedback.heavyImpact();
      String errorMessage = 'حدث خطأ في إنشاء الحساب';
      
      switch (e.code) {
        case 'weak-password':
        errorMessage = 'كلمة المرور ضعيفة جداً';
          break;
        case 'email-already-in-use':
        errorMessage = 'البريد الإلكتروني مستخدم بالفعل';
          break;
        case 'invalid-email':
          errorMessage = 'البريد الإلكتروني غير صحيح';
          break;
        case 'operation-not-allowed':
          errorMessage = 'إنشاء الحسابات غير مفعل';
          break;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ غير متوقع: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
        body: SafeArea(
            child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                SizedBox(height: size.height * 0.05),
                
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset(0, -0.3),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: _animationController,
                      curve: Curves.elasticOut,
                    )),
                    child: Column(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary.withOpacity(0.2),
                                blurRadius: 20,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'images/ashur.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'أشور',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(height: 32),
                
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: _animationController,
                      curve: Curves.elasticOut,
                    )),
                    child: Text(
                      'إنشاء حساب جديد',
                    style: TextStyle(
                        color: colorScheme.onSurface,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                
                SizedBox(height: 8),
                
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    'افضل تطبيق تواصل اجتماعي عراقي',
                    style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                SizedBox(height: size.height * 0.06),
                
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.outline.withOpacity(0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withOpacity(0.1),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _usernameController,
                        enabled: !_isLoading,
                        textDirection: TextDirection.rtl,
                        decoration: InputDecoration(
                          labelText: 'اسم المستخدم',
                          labelStyle: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(20),
                          prefixIcon: Icon(
                            Icons.person_outline,
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 16,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'يرجى إدخال اسم المستخدم';
                          }
                          if (value.length < 3) {
                            return 'اسم المستخدم يجب أن يكون 3 أحرف على الأقل';
                          }
                          if (!RegExp(r'^[a-z0-9_]+$').hasMatch(value)) {
                            return 'اسم المستخدم يجب أن يكون أحرف إنجليزية صغيرة وأرقام أو شرطة سفلية فقط بدون رموز أو مسافات';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                ),
                
                SizedBox(height: 20),
                
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.outline.withOpacity(0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withOpacity(0.1),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _emailController,
                        enabled: !_isLoading,
                        keyboardType: TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: 'البريد الإلكتروني',
                          labelStyle: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(20),
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 16,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'يرجى إدخال البريد الإلكتروني';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                            return 'يرجى إدخال بريد إلكتروني صحيح';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                ),
                
                SizedBox(height: 20),
                
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.outline.withOpacity(0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withOpacity(0.1),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _passwordController,
                        enabled: !_isLoading,
                        obscureText: _obscurePassword,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور',
                          labelStyle: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(20),
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                        setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 16,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'يرجى إدخال كلمة المرور';
                          }
                          if (value.length < 6) {
                            return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                ),
                
                SizedBox(height: 20),
                
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.outline.withOpacity(0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withOpacity(0.1),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _confirmPasswordController,
                        enabled: !_isLoading,
                        obscureText: _obscureConfirmPassword,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: 'تأكيد كلمة المرور',
                          labelStyle: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(20),
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _obscureConfirmPassword = !_obscureConfirmPassword;
                              });
                            },
                          ),
                        ),
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 16,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'يرجى تأكيد كلمة المرور';
                          }
                          if (value != _passwordController.text) {
                            return 'كلمة المرور غير متطابقة';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                ),
                
                SizedBox(height: 32),
                
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                      child: Container(
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
                            color: colorScheme.primary.withOpacity(0.3),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _isLoading ? null : _signUp,
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
                                      SizedBox(width: 12),
                                      Text(
                                        'جاري إنشاء الحساب...',
                                        style: TextStyle(
                                          color: colorScheme.onPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.person_add,
                                        color: colorScheme.onPrimary,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'إنشاء الحساب',
                                  style: TextStyle(
                                          color: colorScheme.onPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                
                SizedBox(height: 24),
                
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            Navigator.pushNamed(context, '/login');
                          }
                        },
                        child: Text(
                          'تسجيل الدخول',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'لديك حساب بالفعل؟ ',
                        style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: size.height * 0.03),
                
                FadeTransition(
                  opacity: _fadeAnimation,
      child: Container(
                    padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.primary.withOpacity(0.2),
                      ),
                    ),
          child: Row(
            children: [
                        Icon(
                          Icons.verified,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                        SizedBox(width: 12),
              Expanded(
                          child: Text(
                            'بإنشاء الحساب، أنت توافق على شروط الاستخدام وسياسة الخصوصية',
                            style: TextStyle(
                              color: colorScheme.onSurface.withOpacity(0.8),
                              fontSize: 14,
                  ),
                ),
              ),
            ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
