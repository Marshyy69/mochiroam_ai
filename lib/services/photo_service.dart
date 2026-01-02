import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PhotoService {
  static Future<String> getCityImage(String query) async {
    final String apiKey = dotenv.env['UNSPLASH_ACCESS_KEY'] ?? '';
    
    if (apiKey.isEmpty) return "";

    try {
      final url = Uri.parse(
          'https://api.unsplash.com/search/photos?query=$query&per_page=1&orientation=landscape&client_id=$apiKey');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          final firstResult = data['results'][0];
          final imageUrl = firstResult['urls']['regular']; // Good quality
          final photographer = firstResult['user']['name'];
          final userLink = firstResult['user']['links']['html'];

          // Return a Markdown Image string with attribution
          return "![Trip to $query]($imageUrl)\n\n"
                 "_${query} photo by [$photographer]($userLink) on Unsplash_\n\n";
        }
      }
    } catch (e) {
      print("⚠️ Error fetching image: $e");
    }
    return ""; // Return empty if anything fails
  }
}