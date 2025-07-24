import 'dart:typed_data';
import 'dart:io' as io;
import 'package:ashur/secrets.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ashur/storage.dart';

class UploadHelper {
  static Future<String?> uploadBytes(BuildContext context, Uint8List bytes, {required String filename}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');
      final uploaded = await StorageHelper.upload(user.uid, bytes, filename: filename);
      return '$ashurStorageUrl?fileId=${uploaded.fileId}';
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في رفع الملف: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return null;
    }
  }

  static Future<String?> uploadFile(BuildContext context, io.File file, {required String filename}) async {
    try {
      final bytes = await file.readAsBytes();
      return await uploadBytes(context, bytes, filename: filename);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في قراءة الملف: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return null;
    }
  }
} 
