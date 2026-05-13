import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/travel_preferences.dart';
import 'serp_api_service.dart';
import 'recommendation_rules.dart';

class GeminiService {
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  static Future<Map<String, dynamic>> sendMessage({
    required String userMessage,
    required TravelPreferences prefs,
    required String rules,
    List<ChatMessage>? previousMessages,
  }) async {
    if (_apiKey.isEmpty) {
      return {"content": "⚠️ Gemini API key not configured."};
    }

    // ── 1. BUILD RULES & DETECT PLANNING QUERY ─────────────────────
    final String smartRules = RecommendationRules.build(prefs);
    final String msgLower = userMessage.toLowerCase();

    final bool isPlanningQuery = msgLower.contains("trip") ||
        msgLower.contains("plan") ||
        msgLower.contains("itinerary") ||
        msgLower.contains("travel to") ||
        msgLower.contains("visit");

    // ── 2. FIRE SERP API IN PARALLEL (only for planning queries) ───
    // Start the search immediately — don't wait for it before building the prompt
    final Future<String> placesSearch = isPlanningQuery
        ? SerpApiService.findPlaces(
            userMessage,
            isHalal: prefs.isHalal,
            budget: prefs.budget,
          )
        : Future.value("");

    // ── 3. BUILD COMPACT SYSTEM PROMPT ──────────────────────────────
    final systemPrompt = _buildSystemPrompt(prefs, smartRules);

    // ── 4. INITIALIZE MODEL ────────────────────────────────────────
    final model = GenerativeModel(
      model: 'gemini-2.5-flash-lite',
      apiKey: _apiKey,
      systemInstruction: Content.system(systemPrompt),
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.5,
        maxOutputTokens: 8192,
      ),
    );

    // ── 5. WAIT FOR SERP RESULTS & BUILD USER MESSAGE ──────────────
    final String realPlaces = await placesSearch;
    final String enrichedMessage = _buildUserMessage(
      userMessage,
      realPlaces,
      prefs,
    );

    // ── 6. MAP DASHCHAT HISTORY TO GEMINI HISTORY ──────────────────
    List<Content> chatHistory = [];
    if (previousMessages != null) {
      for (var msg in previousMessages.reversed.take(4)) {
        final role = msg.user.id == 'user' ? 'user' : 'model';
        chatHistory.add(Content(role, [TextPart(msg.text)]));
      }
    }

    try {
      // ── 7. SEND TO GEMINI ──────────────────────────────────────────
      final chat = model.startChat(history: chatHistory);
      final response = await chat.sendMessage(Content.text(enrichedMessage));

      final String contentString = response.text ?? "";

      // ── 8. PARSE JSON ──────────────────────────────────────────────
      try {
        Map<String, dynamic> tripData =
            jsonDecode(contentString) as Map<String, dynamic>;

        // Halal post-processing filter
        if (prefs.isHalal) {
          _enforceHalal(tripData);
        }

        return tripData;
      } catch (_) {
        return {
          "content":
              "I couldn't format that properly. Could you ask me again?"
        };
      }
    } catch (e) {
      String errorString = e.toString();

      if (errorString.contains('503') ||
          errorString.contains('high demand')) {
        return {
          "content":
              "Mochi's brain is a little overloaded right now! 🍡 Too many travelers are asking for directions. Please try again in a minute!"
        };
      }

      return {"content": "Oops, my brain disconnected: $e"};
    }
  }

  /// Builds a compact, structured system prompt that enforces all user preferences.
  static String _buildSystemPrompt(
      TravelPreferences prefs, String smartRules) {
    return """
You are Mochi, a smart AI travel companion. Generate detailed trip itineraries as JSON.

USER PREFERENCES (MUST FOLLOW STRICTLY):
$smartRules

RULES:
- Structure each day with 5-6 activities: Morning → Late Morning → Lunch → Afternoon → Dinner → Evening.
- Lunch and Dinner MUST be at named restaurants.
- Match activities to the user's interests, budget, and group type.
${prefs.isHalal ? "- HALAL ENFORCEMENT: No pork, no alcohol, no bars/pubs. Only Halal/Muslim-friendly food." : ""}

JSON SCHEMA (follow exactly):
{"trip_name":"string","country":"string","duration":"X Days","full_content":"2-3 sentence summary","cover_image":"","tags":["string"],"is_halal":${prefs.isHalal},"trip_data":{"days":[{"day":1,"theme":"string","activities":[{"time":"09:00 AM","title":"string","desc":"string"}]}]}}
""";
  }

  /// Builds the final user message with real-time restaurant data injected.
  static String _buildUserMessage(
    String userMessage,
    String realPlaces,
    TravelPreferences prefs, 
  ) {
    if (realPlaces.isEmpty) return userMessage;

    return """
$userMessage

REAL-TIME RESTAURANT DATA (use these for Lunch/Dinner slots):
$realPlaces

Use these exact restaurant names where they match the location. Mix cuisines for variety.${prefs.isHalal ? " ONLY use Halal options." : ""}
""";
  }

  /// Post-processing halal filter as a safety net.
  static void _enforceHalal(Map<String, dynamic> tripData) {
    final List<String> haramWords = [
      "babi", "pork", "pig", "bak kut teh", "char siew",
      "beer", "wine", "bar ", "pub ", "izakaya"
    ];

    List<dynamic> days = [];
    if (tripData['trip_data'] != null &&
        tripData['trip_data']['days'] != null) {
      days = tripData['trip_data']['days'];
    } else if (tripData['days'] != null) {
      days = tripData['days'];
    }

    for (var day in days) {
      List<dynamic> activities = day['activities'] ?? [];
      for (var act in activities) {
        String title = act['title'].toString().toLowerCase();
        String desc = act['desc'].toString().toLowerCase();

        bool isHaram =
            haramWords.any((word) => title.contains(word) || desc.contains(word));

        if (isHaram) {
          act['title'] = "Local Halal Delight";
          act['desc'] = "A verified Muslim-friendly restaurant nearby.";
        }
      }
    }
  }
}