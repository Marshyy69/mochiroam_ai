import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class SerpApiService {
  static String get apiKey => dotenv.env['SERP_API_KEY'] ?? '';

  // Fetches a list of Halal restaurants for a specific city/query
  static Future<String> findHalalPlaces(String query) async {
    // We append "Halal food" to whatever the user asked for context
    // E.g. "Tokyo" -> "Halal food in Tokyo"
    final searchUrl = Uri.parse(
      'https://serpapi.com/search.json?engine=google_maps&q=halal+food+in+$query&type=search&api_key=$apiKey'
    );

    try {
      final response = await http.get(searchUrl);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Check if we have local results
        if (data['local_results'] != null) {
          final results = data['local_results'] as List;
          
          // Take the top 5 results only (to save token space)
          List<String> places = [];
          for (var item in results.take(5)) {
            final name = item['title'];
            final rating = item['rating'] ?? 'N/A';
            final address = item['address'] ?? 'Address unavail';
            places.add("- $name (Rating: $rating) located at $address");
          }
          
          return places.join("\n");
        }
      }
    } catch (e) {
      print("SerpApi Error: $e");
    }
    return ""; // Return empty string if fails, so app doesn't crash
  }
}