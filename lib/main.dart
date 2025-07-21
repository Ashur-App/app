

import 'package:ashur/auth.dart';
import 'package:ashur/firebase_options.dart';
import 'package:ashur/screens/foryou.dart';
import 'package:ashur/screens/login.dart';
import 'package:ashur/screens/newacc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/addscreen.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'dart:async';
import 'screens/profile_analytics.dart';
import 'screens/settings.dart';
import 'screens/notification_center.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notifications.dart';
import 'custom_theme.dart';
import 'screens/onboarding.dart';
import 'screens/multi_account.dart';
final customThemeNotifier = ValueNotifier<CustomTheme?>(null);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    if (kDebugMode) {
      print("Firebase init error: $e");
    }
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  ThemeMode _themeMode = ThemeMode.system;
  double _fontSize = 1.0;
  String _themeModeString = 'system';
  bool _onboardingComplete = false;
  bool _prefsLoaded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _loadPrefs();
    NotificationService.initialize(context);
    customThemeNotifier.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    setState(() {});
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString('themeMode') ?? 'system';
    _themeModeString = theme;
    double? font = prefs.getDouble('fontSize');
    if (font == null || font.isNaN || font <= 0) {
      font = 1.0;
      await prefs.setDouble('fontSize', 1.0);
    }
    _onboardingComplete = prefs.getBool('onboardingComplete') ?? false;
    _prefsLoaded = true;
    setState(() {});
    print('[DEBUG] Loaded fontSize: $font');
    String? selectedCustomThemeName = await CustomThemeManager.loadSelectedThemeName();
    List<CustomTheme> customThemes = await CustomThemeManager.loadLocalThemes();
    CustomTheme? customTheme;
    if (_themeModeString == 'custom' && selectedCustomThemeName != null) {
      try {
        customTheme = customThemes.firstWhere((t) => t.name == selectedCustomThemeName);
      } catch (_) {
        customTheme = null;
      }
    } else {
      customTheme = null;
    }
    _themeMode = theme == 'dark' ? ThemeMode.dark : theme == 'light' ? ThemeMode.light : ThemeMode.system;
    _fontSize = font;
    customThemeNotifier.value = customTheme;
    setState(() {});
  }

  @override
  void dispose() {
    _animationController.dispose();
    customThemeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  TextTheme _patchTextTheme(TextTheme base, {double defaultSize = 14}) {
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(fontSize: base.displayLarge?.fontSize ?? defaultSize),
      displayMedium: base.displayMedium?.copyWith(fontSize: base.displayMedium?.fontSize ?? defaultSize),
      displaySmall: base.displaySmall?.copyWith(fontSize: base.displaySmall?.fontSize ?? defaultSize),
      headlineLarge: base.headlineLarge?.copyWith(fontSize: base.headlineLarge?.fontSize ?? defaultSize),
      headlineMedium: base.headlineMedium?.copyWith(fontSize: base.headlineMedium?.fontSize ?? defaultSize),
      headlineSmall: base.headlineSmall?.copyWith(fontSize: base.headlineSmall?.fontSize ?? defaultSize),
      titleLarge: base.titleLarge?.copyWith(fontSize: base.titleLarge?.fontSize ?? defaultSize),
      titleMedium: base.titleMedium?.copyWith(fontSize: base.titleMedium?.fontSize ?? defaultSize),
      titleSmall: base.titleSmall?.copyWith(fontSize: base.titleSmall?.fontSize ?? defaultSize),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: base.bodyLarge?.fontSize ?? defaultSize),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: base.bodyMedium?.fontSize ?? defaultSize),
      bodySmall: base.bodySmall?.copyWith(fontSize: base.bodySmall?.fontSize ?? defaultSize),
      labelLarge: base.labelLarge?.copyWith(fontSize: base.labelLarge?.fontSize ?? defaultSize),
      labelMedium: base.labelMedium?.copyWith(fontSize: base.labelMedium?.fontSize ?? defaultSize),
      labelSmall: base.labelSmall?.copyWith(fontSize: base.labelSmall?.fontSize ?? defaultSize),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_prefsLoaded) {
      return MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    return ValueListenableBuilder<CustomTheme?>(
      valueListenable: customThemeNotifier,
      builder: (context, customTheme, _) {
        return DynamicColorBuilder(
          builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
            ColorScheme lightColorScheme;
            ColorScheme darkColorScheme;
            if (_themeModeString == 'custom' && customTheme != null) {
              lightColorScheme = ColorScheme(
                brightness: Brightness.light,
                primary: customTheme.primaryColor,
                onPrimary: customTheme.textColor,
                secondary: customTheme.accentColor,
                onSecondary: customTheme.textColor,
                error: Colors.red,
                onError: Colors.white,
                surface: customTheme.backgroundColor,
                onSurface: customTheme.textColor,
              );
              darkColorScheme = ColorScheme(
                brightness: Brightness.dark,
                primary: customTheme.primaryColor,
                onPrimary: customTheme.textColor,
                secondary: customTheme.accentColor,
                onSecondary: customTheme.textColor,
                error: Colors.red,
                onError: Colors.white,
                surface: customTheme.backgroundColor,
                onSurface: customTheme.textColor,
              );
            } else if (lightDynamic != null && darkDynamic != null) {
              lightColorScheme = lightDynamic.harmonized();
              darkColorScheme = darkDynamic.harmonized();
            } else {
              lightColorScheme = ColorScheme.fromSeed(seedColor: ColorSeed.baseColor.color);
              darkColorScheme = ColorScheme.fromSeed(seedColor: ColorSeed.baseColor.color, brightness: Brightness.dark);
            }
            final safeFontSize = (_fontSize.isNaN || _fontSize <= 0) ? 1.0 : _fontSize;
            if (!_onboardingComplete) {
              return MaterialApp(
                theme: ThemeData(
                  colorScheme: lightColorScheme,
                  useMaterial3: true,
                  fontFamily: '3rby',
                  textTheme: _patchTextTheme(ThemeData.light().textTheme).apply(fontSizeFactor: safeFontSize),
                ),
                darkTheme: ThemeData(
                  colorScheme: darkColorScheme,
                  useMaterial3: true,
                  fontFamily: '3rby',
                  textTheme: _patchTextTheme(ThemeData.dark().textTheme).apply(fontSizeFactor: safeFontSize),
                ),
                themeMode: _themeMode,
                home: OnboardingScreen(onFinish: () {
                  setState(() {
                    _onboardingComplete = true;
                  });
                }),
              );
            }
            return Shortcuts(
                shortcuts: <LogicalKeySet, Intent>{
                  LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
                },
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: MaterialApp(
                    debugShowCheckedModeBanner: false,
                    title: 'Ashur',
                    navigatorObservers: [routeObserver],
                    theme: ThemeData(
                      colorScheme: lightColorScheme,
                      useMaterial3: true,
                      fontFamily: '3rby',
                      textTheme: _patchTextTheme(ThemeData.light().textTheme).apply(fontSizeFactor: safeFontSize),
                      pageTransitionsTheme: const PageTransitionsTheme(
                        builders: {
                          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                        },
                      ),
                    ),
                    darkTheme: ThemeData(
                      colorScheme: darkColorScheme,
                      useMaterial3: true,
                      fontFamily: '3rby',
                      textTheme: _patchTextTheme(ThemeData.dark().textTheme).apply(fontSizeFactor: safeFontSize),
                      pageTransitionsTheme: const PageTransitionsTheme(
                        builders: {
                          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                        },
                      ),
                    ),
                    themeMode: _themeMode,
                    routes: {
                      '/': (context) => const Auth(),
                      '/signup': (context) => SignUpScreen(),
                      '/login': (context) => LoginScreen(),
                      'Foryouscreen': (context) => foryouscreen(),
                      'Signupscreen': (context) => SignUpScreen(),
                      'Loginscreen': (context) => LoginScreen(),
                      'Addscreen': (context) => AddScreen(),
                      ProfileAnalyticsPage.routeName: (context) => const ProfileAnalyticsPage(),
                      '/settings': (context) => const SettingsScreen(),
                      '/notifications': (context) => const NotificationCenterScreen(),
                    },
                  ),
                ));
          },
        );
      },
    );
  }
}

enum ColorSeed {
  baseColor('M3 Baseline', Color(0xff6750a4)),
  indigo('Indigo', Colors.indigo),
  blue('Blue', Colors.blue),
  teal('Teal', Colors.teal),
  green('Green', Colors.green),
  yellow('Yellow', Colors.yellow),
  orange('Orange', Colors.orange),
  deepOrange('Deep Orange', Colors.deepOrange),
  pink('Pink', Colors.pink);

  const ColorSeed(this.label, this.color);
  final String label;
  final Color color;
}
