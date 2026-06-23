import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static String get _cloudName => dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  static String get _uploadPreset =>
      dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';

  /// Uploads a single image file to Cloudinary and returns the secure URL.
  /// Returns empty string on failure.
  static Future<String> uploadImage(File imageFile) async {
    if (_cloudName.isEmpty || _uploadPreset.isEmpty) return "";

    final uri = Uri.parse(
        "https://api.cloudinary.com/v1_1/$_cloudName/image/upload");

    try {
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response = await request.send().timeout(
            const Duration(seconds: 30),
          );

      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        final data = jsonDecode(body);
        return data['secure_url'] ?? "";
      }
    } catch (_) {
      // Upload failed — caller handles the error
    }
    return "";
  }

  /// Uploads multiple image files in parallel. Returns list of URLs.
  /// Skips any failed uploads (returns only successful URLs).
  static Future<List<String>> uploadImages(List<File> files) async {
    final results = await Future.wait(
      files.map((file) => uploadImage(file)),
    );
    return results.where((url) => url.isNotEmpty).toList();
  }
}
