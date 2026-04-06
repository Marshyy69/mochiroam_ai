import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class SerpApiService {
  static String get apiKey => dotenv.env['SERP_API_KEY'] ?? '';

  // ✅ UPDATED: Accepts 'isHalal' to switch between "Halal" and "Best/Popular"
  static Future<String> findPlaces(String userMessage, {required bool isHalal}) async {
    if (apiKey.isEmpty) return "";

    String location = _extractLocation(userMessage);
    if (location.isEmpty) location = userMessage; 

    print("📍 Detected Location: $location | Halal Mode: $isHalal");

    // 1. DYNAMIC QUERIES
    List<String> queries;
    
    if (isHalal) {
      // 🟢 HALAL MODE: Strict filters
      queries = [
        "Halal Ramen in $location",
        "Halal Sushi in $location",
        "Halal Wagyu or Yakiniku in $location",
        "Halal Indian or Malay food in $location" 
      ];
    } else {
      // 🔴 GENERAL MODE: Top Rated / Popular spots (No restrictions)
      queries = [
        "Best Ramen in $location",
        "Top rated Sushi in $location",
        "Famous street food in $location",
        "Best cafes in $location",
        "Must try local food in $location"
      ];
    }

    List<String> allPlaces = [];

    // 2. RUN PARALLEL SEARCHES (Top 3 from each category)
    for (String query in queries) {
      String results = await _searchGoogleMaps(query, limit: 3);
      if (results.isNotEmpty) {
        allPlaces.add(results);
      }
    }

    // Shuffle so Ramen isn't always the first suggestion
    allPlaces.shuffle(Random());
    
    return allPlaces.join("\n");
  }

  // Helper: The actual API call
  static Future<String> _searchGoogleMaps(String query, {int limit = 3}) async {
    final uri = Uri.parse("https://serpapi.com/search.json");
    final params = {
      "engine": "google_maps",
      "q": query,
      "type": "search",
      "api_key": apiKey,
      "hl": "en"
    };

    try {
      Uri searchUrl = uri.replace(queryParameters: params);

      // Web Proxy Fix
      if (kIsWeb) {
        final proxyUrl = "https://corsproxy.io/?${Uri.encodeComponent(searchUrl.toString())}";
        searchUrl = Uri.parse(proxyUrl);
      }

      final response = await http.get(searchUrl);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['local_results'] != null) {
          final results = data['local_results'] as List;
          
          List<String> places = [];
          for (var item in results.take(limit)) {
            final name = item['title'];
            final rating = item['rating'] ?? 'N/A';
            final address = item['address'] ?? 'Unknown Location';
            final type = item['type'] ?? 'Restaurant';
            
            // Format: "- Name (Rating) [Type] - Loc: Address"
            places.add("- $name ($rating⭐) [$type] - Loc: $address");
          }
          return places.join("\n");
        }
      }
    } catch (e) {
      print("⚠️ SerpApi Failed for '$query': $e");
    }
    return "";
  }

  static String _extractLocation(String text) {
    final regexes = [
      RegExp(r"(?:trip|travel|journey|flight) to\s+([a-zA-Z\s]+)", caseSensitive: false),
      RegExp(r"(?:visit|explore|in)\s+([a-zA-Z\s]+)", caseSensitive: false),
    ];

    for (var regex in regexes) {
      final match = regex.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        String found = match.group(1)!.trim();
        found = found.replaceAll(RegExp(r"\s+(please|now|soon|tomorrow)$", caseSensitive: false), "");
        return found;
      }
    }
    return ""; 
  }
}