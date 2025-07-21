

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['email'] is String) {
      _emailController.text = args['email'];
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      HapticFeedback.lightImpact();
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      Navigator.pop(context, FirebaseAuth.instance.currentUser);

              HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تسجيل الدخول بنجاح'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } on FirebaseAuthException catch (e) {
      HapticFeedback.heavyImpact();
      String errorMessage = 'حدث خطأ في تسجيل الدخول';
      
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'البريد الإلكتروني غير مسجل';
          break;
        case 'wrong-password':
          errorMessage = 'كلمة المرور غير صحيحة';
          break;
        case 'invalid-email':
          errorMessage = 'البريد الإلكتروني غير صحيح';
          break;
        case 'user-disabled':
          errorMessage = 'تم تعطيل هذا الحساب';
          break;
        case 'too-many-requests':
          errorMessage = 'تم تجاوز عدد المحاولات المسموح';
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
                SizedBox(height: size.height * 0.1),
                
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
                      'مرحباً بك مرة أخرى',
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
                    'سجل دخولك للوصول إلى حسابك',
                    style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                SizedBox(height: size.height * 0.08),
                
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
                
                SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : () async {
                      final emailController = TextEditingController(text: _emailController.text);
                      final result = await showDialog<String>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('إعادة تعيين كلمة المرور'),
                          content: TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'البريد الإلكتروني',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('إلغاء'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, emailController.text.trim()),
                              child: Text('إرسال'),
                            ),
                          ],
                        ),
                      );
                      if (result != null && result.isNotEmpty) {
                        try {
                          await FirebaseAuth.instance.sendPasswordResetEmail(email: result);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني'), backgroundColor: Colors.green),
                          );
                        } on FirebaseAuthException catch (e) {
                          String msg = 'حدث خطأ. حاول مرة أخرى';
                          if (e.code == 'user-not-found') msg = 'البريد الإلكتروني غير مسجل';
                          if (e.code == 'invalid-email') msg = 'البريد الإلكتروني غير صحيح';
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(msg), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    child: Text('نسيت كلمة المرور؟'),
                  ),
                ),
                
                SizedBox(height: 24),
                
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
                          onTap: _isLoading ? null : _login,
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
                                        'جاري تسجيل الدخول...',
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
                                        Icons.login,
                                        color: colorScheme.onPrimary,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'تسجيل الدخول',
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
                          Navigator.pushNamed(context, '/signup');
                        },
                        child: Text(
                          'إنشاء حساب جديد',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'ليس لديك حساب؟ ',
                        style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: size.height * 0.05),
                
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
                          Icons.security,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'بياناتك محمية ومشفرة بالكامل',
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
