import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class PhotoService {
  /// Returns a raw image URL for the given city/query, or empty string on failure.
  static Future<String> getCityImage(String query) async {
    final String apiKey = dotenv.env['UNSPLASH_ACCESS_KEY'] ?? '';

    if (apiKey.isEmpty) return "";

    try {
      final url = Uri.parse(
          'https://api.unsplash.com/search/photos?query=$query&per_page=1&orientation=landscape&client_id=$apiKey');

      final response = await http
          .get(url)
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          return data['results'][0]['urls']['regular'] ?? "";
        }
      }
    } catch (_) {
      // Timeout or network error — fall back to default image
    }
    return "";
  }
}