import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class SerpApiService {
  static String get apiKey => dotenv.env['SERP_API_KEY'] ?? '';

  /// Finds real restaurant/food data for a location.
  /// Now location-aware and budget-sensitive instead of hardcoded Japanese cuisine.
  static Future<String> findPlaces(
    String userMessage, {
    required bool isHalal,
    String budget = 'Standard',
  }) async {
    if (apiKey.isEmpty) return "";

    String location = _extractLocation(userMessage);
    if (location.isEmpty) location = userMessage;

    // Build location-appropriate queries based on halal + budget
    final queries = _buildQueries(location, isHalal: isHalal, budget: budget);

    // Run all searches in parallel with a timeout
    try {
      final results = await Future.wait(
        queries.map((query) => _searchGoogleMaps(query, limit: 3)),
      ).timeout(
        const Duration(seconds: 6),
        onTimeout: () => List.filled(queries.length, ""),
      );

      final allPlaces = results.where((r) => r.isNotEmpty).toList();
      allPlaces.shuffle(Random());
      return allPlaces.join("\n");
    } catch (_) {
      return ""; // Graceful degradation — AI still works without real-time data
    }
  }

  /// Builds search queries tailored to the destination, halal mode, and budget.
  static List<String> _buildQueries(
    String location, {
    required bool isHalal,
    required String budget,
  }) {
    final String foodPrefix;
    final String budgetHint;

    // Budget-aware food query prefixes
    if (budget.contains("Budget")) {
      budgetHint = "cheap";
      foodPrefix = isHalal ? "Affordable Halal" : "Cheap local";
    } else if (budget.contains("Luxury")) {
      budgetHint = "fine dining";
      foodPrefix = isHalal ? "Halal fine dining" : "Best fine dining";
    } else {
      budgetHint = "popular";
      foodPrefix = isHalal ? "Halal" : "Top rated";
    }

    if (isHalal) {
      return [
        "$foodPrefix restaurants in $location",
        "Halal food near attractions in $location",
        "Muslim friendly cafes in $location",
      ];
    } else {
      return [
        "$foodPrefix restaurants in $location",
        "Famous $budgetHint street food in $location",
        "Best cafes in $location",
      ];
    }
  }

  /// Searches Google Maps via SerpAPI with a per-request timeout.
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
        final proxyUrl =
            "https://corsproxy.io/?${Uri.encodeComponent(searchUrl.toString())}";
        searchUrl = Uri.parse(proxyUrl);
      }

      final response = await http
          .get(searchUrl)
          .timeout(const Duration(seconds: 5));

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

            places.add("- $name ($rating⭐) [$type] - Loc: $address");
          }
          return places.join("\n");
        }
      }
    } catch (_) {
      // Timeout or network error — fail silently
    }
    return "";
  }

  /// Extracts location from natural language input.
  static String _extractLocation(String text) {
    final regexes = [
      RegExp(r"(?:trip|travel|journey|flight) to\s+([a-zA-Z\s]+)",
          caseSensitive: false),
      RegExp(r"(?:visit|explore|in)\s+([a-zA-Z\s]+)", caseSensitive: false),
    ];

    for (var regex in regexes) {
      final match = regex.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        String found = match.group(1)!.trim();
        found = found.replaceAll(
            RegExp(r"\s+(please|now|soon|tomorrow)$", caseSensitive: false),
            "");
        return found;
      }
    }
    return "";
  }
}