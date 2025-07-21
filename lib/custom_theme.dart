import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert';

class CustomTheme {
  final String name;
  final Color primaryColor;
  final Color accentColor;
  final Color backgroundColor;
  final Color textColor;

  CustomTheme({
    required this.name,
    required this.primaryColor,
    required this.accentColor,
    required this.backgroundColor,
    required this.textColor,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'primaryColor': primaryColor.value,
        'accentColor': accentColor.value,
        'backgroundColor': backgroundColor.value,
        'textColor': textColor.value,
      };

  factory CustomTheme.fromMap(Map<String, dynamic> map) => CustomTheme(
        name: map['name'],
        primaryColor: Color(map['primaryColor']),
        accentColor: Color(map['accentColor']),
        backgroundColor: Color(map['backgroundColor']),
        textColor: Color(map['textColor']),
      );

  static List<CustomTheme> listFromJson(String jsonStr) {
    final List<dynamic> decoded = json.decode(jsonStr);
    return decoded.map((e) => CustomTheme.fromMap(e)).toList();
  }

  static String listToJson(List<CustomTheme> themes) {
    return json.encode(themes.map((e) => e.toMap()).toList());
  }
}

class CustomThemeManager {
  static const String _prefsKey = 'customThemes';
  static const String _selectedThemeKey = 'selectedCustomTheme';
  static Future<List<CustomTheme>> loadLocalThemes() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefsKey);
    if (jsonStr == null) return [];
    try {
      return CustomTheme.listFromJson(jsonStr);
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveLocalThemes(List<CustomTheme> themes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, CustomTheme.listToJson(themes));
  }

  static Future<List<CustomTheme>> loadCloudThemes(String uid) async {
    final ref = FirebaseDatabase.instance.ref('users/$uid/customThemes');
    final snap = await ref.get();
    if (!snap.exists || snap.value == null) return [];
    try {
      final List<dynamic> data = snap.value as List<dynamic>;
      return data.map((e) => CustomTheme.fromMap(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveCloudThemes(String uid, List<CustomTheme> themes) async {
    final ref = FirebaseDatabase.instance.ref('users/$uid/customThemes');
    await ref.set(themes.map((e) => e.toMap()).toList());
  }

  static Future<String?> loadSelectedThemeName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedThemeKey);
  }

  static Future<void> saveSelectedThemeName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedThemeKey, name);
  }

  static Future<String?> loadCloudSelectedTheme(String uid) async {
    final ref = FirebaseDatabase.instance.ref('users/$uid/selectedCustomTheme');
    final snap = await ref.get();
    if (!snap.exists || snap.value == null) return null;
    return snap.value as String?;
  }

  static Future<void> saveCloudSelectedTheme(String uid, String name) async {
    final ref = FirebaseDatabase.instance.ref('users/$uid/selectedCustomTheme');
    await ref.set(name);
  }

  static Future<List<CustomTheme>> syncThemes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return await loadLocalThemes();
    final cloudThemes = await loadCloudThemes(user.uid);
    if (cloudThemes.isNotEmpty) {
      await saveLocalThemes(cloudThemes);
      return cloudThemes;
    } else {
      final localThemes = await loadLocalThemes();
      if (localThemes.isNotEmpty) {
        await saveCloudThemes(user.uid, localThemes);
      }
      return localThemes;
    }
  }

  static Future<String?> syncSelectedTheme() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return await loadSelectedThemeName();
    final cloudSelected = await loadCloudSelectedTheme(user.uid);
    if (cloudSelected != null) {
      await saveSelectedThemeName(cloudSelected);
      return cloudSelected;
    } else {
      final localSelected = await loadSelectedThemeName();
      if (localSelected != null) {
        await saveCloudSelectedTheme(user.uid, localSelected);
      }
      return localSelected;
    }
  }
} 