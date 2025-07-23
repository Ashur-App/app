import 'package:ashur/secrets.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';
Future<bool> checkForUpdate() async {
  final client = http.Client();
  try {
    final url = Uri.parse('https://api.github.com/repos/$repo/releases/latest');
    final response = await client.get(url);
    if (response.statusCode != 200) {
      return false;
    }

    final jsonResponse = jsonDecode(response.body);
    final String? tagName = jsonResponse['tag_name'];
    if (tagName == null) return false;
    final packageInfo = await PackageInfo.fromPlatform();
    final String currentVersion = packageInfo.version;
    return tagName != 'v$currentVersion';
  } catch (e) {
    return false;
  } finally {
    client.close();
  }
}
