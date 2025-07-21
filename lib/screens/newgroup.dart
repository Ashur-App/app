

import 'package:ashur/secrets.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' as io;
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ashur/storage.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import 'dart:typed_data';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  _CreateGroupScreenState createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  io.File? _selectedImage;
  bool _isCreating = false;
  bool _isUploading = false;

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        final imageBytes = await pickedFile.readAsBytes();
        final editedImage = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ImageEditor(
              image: imageBytes,
            ),
          ),
        );
        if (editedImage != null && editedImage is Uint8List) {
          final tempDir = await io.Directory.systemTemp.createTemp('edited_image');
          final tempFile = io.File('${tempDir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await tempFile.writeAsBytes(editedImage);
          setState(() {
            _selectedImage = tempFile;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في اختيار الصورة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _uploadImage(io.File image) async {
    try {
      setState(() {
        _isUploading = true;
      });

      final bytes = await image.readAsBytes();
      String fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(image.path)}';
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');
      final uploaded = await StorageHelper.upload(user.uid, bytes, filename: fileName);
      final proxyUrl = '$ashurStorageUrl?fileId=${uploaded.fileId}';
      return proxyUrl;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في رفع الصورة: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _createGroup() async {
    final groupName = _groupNameController.text.trim();
    if (groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال اسم المجموعة'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _uploadImage(_selectedImage!);
        if (imageUrl == null) {
          setState(() {
            _isCreating = false;
          });
          return;
        }
      }

      final groupId = Uuid().v4();
      final newGroupRef = FirebaseDatabase.instance.ref('groups/$groupId');

      await newGroupRef.set({
        'name': groupName,
        'pic': imageUrl ?? '',
        'owner': FirebaseAuth.instance.currentUser?.uid,
        'id': groupId,
        'description': '',
        'created_at': DateTime.now().toUtc().toString(),
        'members': [FirebaseAuth.instance.currentUser?.uid],
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إنشاء المجموعة بنجاح'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في إنشاء المجموعة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isCreating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'إنشاء مجموعة جديدة',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 20),
            
            
            Center(
        child: Column(
          children: [
            GestureDetector(
                    onTap: _isCreating ? null : _pickImage,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(60),
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
              child: _selectedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(58),
                              child: Stack(
                                children: [
                                  Image.file(
                      _selectedImage!,
                                    width: 120,
                                    height: 120,
                      fit: BoxFit.cover,
                                  ),
                                  if (_isUploading)
                                    Container(
                                      width: 120,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(58),
                                      ),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: colorScheme.onPrimary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.camera_alt_outlined,
                                  size: 40,
                                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'إضافة صورة',
                                  style: TextStyle(
                                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'انقر لإضافة صورة المجموعة',
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 32),
            
            
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: TextField(
              controller: _groupNameController,
                enabled: !_isCreating,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                labelText: 'اسم المجموعة',
                  labelStyle: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  prefixIcon: Icon(
                    Icons.group_outlined,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 16,
                ),
              ),
            ),
            
            SizedBox(height: 32),
            
            
            Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary,
                    colorScheme.primary.withValues(alpha: 0.8),
                  ],
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _isCreating ? null : _createGroup,
                  child: Center(
                    child: _isCreating
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
                                'جاري الإنشاء...',
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
                                Icons.add_circle_outline,
                                color: colorScheme.onPrimary,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'إنشاء المجموعة',
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
            
            SizedBox(height: 16),
            
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'ستتمكن من إضافة أعضاء للمجموعة بعد إنشائها',
                      style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
                  ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }
}
