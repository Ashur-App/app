import 'dart:typed_data';
import 'dart:convert';
import 'package:ashur/secrets.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
class TelegramStorageService {
  final String baseUrl;
  final String apiKey; 
  TelegramStorageService({
    required this.baseUrl,
    required this.apiKey,
  });

  Map<String, String> get _headers => {
    'X-API-Key': apiKey,
    'Content-Type': 'application/octet-stream',
  };

  Future<bool> checkUserExists(String userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/storage?action=check-user&userId=$userId'),
      headers: {'X-API-Key': apiKey},
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['exists'] ?? false;
    }
    
    throw Exception('Failed to check user: ${response.body}');
  }

  Future<String> getDirectUrl(String fileId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/storage?action=get-url&fileId=$fileId'),
      headers: {'X-API-Key': apiKey},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['url'];
    }

    throw Exception('Failed to get URL: ${response.body}');
  }

  Future<StorageFile> uploadFile(
    String userId,
    Uint8List fileData, {
    String? filename,
  }) async {
    final uri = Uri.parse('$baseUrl/api/storage').replace(queryParameters: {
      'action': 'upload',
      'userId': userId,
      if (filename != null) 'filename': filename,
    });

    final response = await http.post(
      uri,
      headers: _headers,
      body: fileData,
    );

    print('Upload response status: ${response.statusCode}');
    print('Upload response body: ${response.body}');
    if (response.statusCode == 200) {
      try {
        final data = json.decode(response.body);
        return StorageFile.fromJson(data['file']);
      } catch (e) {
        print('JSON decode error: $e');
        print('Problematic body: \\${response.body}');
        rethrow;
      }
    }

    throw Exception('Upload failed: ${response.body}');
  }

  Future<Uint8List> downloadFile(String fileId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/storage?fileId=$fileId'),
      headers: {'X-API-Key': apiKey},
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    }

    throw Exception('Download failed: ${response.body}');
  }

  Future<List<StorageFile>> listUserFiles(String userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/storage?action=list-files&userId=$userId'),
      headers: {'X-API-Key': apiKey},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['files'] as List)
          .map((file) => StorageFile.fromJson(file))
          .toList();
    }

    throw Exception('Failed to list files: ${response.body}');
  }

  Future<void> deleteFile(String fileId, String messageId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/storage?fileId=$fileId&messageId=$messageId'),
      headers: {'X-API-Key': apiKey},
    );

    if (response.statusCode != 200) {
      throw Exception('Delete failed: ${response.body}');
    }
  }
}

class StorageFile {
  final String fileId;
  final String filename;
  final int size;
  final String? uploadDate;
  final int? messageId;
  final String? mediaType;
  final String? directUrl;

  StorageFile({
    required this.fileId,
    required this.filename,
    required this.size,
    this.uploadDate,
    this.messageId,
    this.mediaType,
    this.directUrl,
  });

  factory StorageFile.fromJson(Map<String, dynamic> json) {
    return StorageFile(
      fileId: json['fileId'],
      filename: json['filename'],
      size: json['size'],
      uploadDate: json['uploadDate'],
      messageId: json['messageId'],
      mediaType: json['mediaType'],
      directUrl: json['directUrl'],
    );
  }
}

class StorageHelper {
  static final TelegramStorageService _service = TelegramStorageService(
    baseUrl: ashurStorageUrl,
    apiKey: ashurStorageApiKey,
  );

  static Future<bool> userExists(String userId) => _service.checkUserExists(userId);
  static Future<StorageFile> upload(String userId, Uint8List data, {String? filename}) => 
      _service.uploadFile(userId, data, filename: filename);
  static Future<Uint8List> download(String fileId) => _service.downloadFile(fileId);
  static Future<String> getDirectUrl(String fileId) => _service.getDirectUrl(fileId);
  static Future<List<StorageFile>> getUserFiles(String userId) => 
      _service.listUserFiles(userId);
  static Future<void> delete(String fileId, String messageId) => 
      _service.deleteFile(fileId, messageId);
}

Future<void> incrementChallengeProgress(String action) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  final uid = user.uid;
  final challengesSnap = await FirebaseDatabase.instance.ref('challenges').get();
  if (!challengesSnap.exists || challengesSnap.value == null) return;
  final challenges = Map<String, dynamic>.from(challengesSnap.value as Map);
  for (final entry in challenges.entries) {
    final key = entry.key;
    final value = entry.value;
    if (value is Map && value['action'] == action) {
      final userChallengeRef = FirebaseDatabase.instance.ref('users/$uid/challenges/$key');
      final userChallengeSnap = await userChallengeRef.get();
      int progress = 0;
      if (userChallengeSnap.exists && userChallengeSnap.value != null && (userChallengeSnap.value as Map)['progress'] != null) {
        progress = (userChallengeSnap.value as Map)['progress'];
      }
      await userChallengeRef.update({'progress': progress + 1});
    }
  }
}