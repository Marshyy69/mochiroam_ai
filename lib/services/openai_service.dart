import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/travel_preferences.dart';
import 'serp_api_service.dart'; 
import 'package:dash_chat_2/dash_chat_2.dart'; 

class OpenAIService {
  static final String _apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';

  static Future<Map<String, dynamic>> sendMessage({
    required String userMessage,
    required TravelPreferences prefs, 
    required String rules,
    List<ChatMessage>? previousMessages,
  }) async {
    if (_apiKey.isEmpty) {
      return {"content": "⚠️ OpenAI API key not configured."};
    }

    final uri = Uri.parse("https://api.openai.com/v1/chat/completions");

    // 1. HALAL & SERPAPI LOGIC
    String dietaryRule = "";
    String realData = "";

    if (prefs.isHalal) {
      if (userMessage.toLowerCase().contains("trip") || 
          userMessage.toLowerCase().contains("plan") ||
          userMessage.toLowerCase().contains("itinerary")) {
        
        print("🔍 Halal Mode ON: Fetching real data from SerpApi...");
        realData = await SerpApiService.findHalalPlaces(userMessage);
      }

      dietaryRule = """
      CRITICAL DIETARY REQUIREMENT:
      The user has a STRICT HALAL preference.
      - You MUST ONLY suggest restaurants that are Halal-certified or known to be Muslim-friendly.
      - I have fetched REAL DATA for you to use below.
      - PRIORITIZE using these specific verified places for Lunch/Dinner:
      $realData
      - If these don't fit the location, you MUST find a specific Halal restaurant name. Do not just say "Halal Restaurant".
      """;
    }

    // 2. SYSTEM PROMPT
    final systemPrompt = """
    You are Mochi AI, a travel assistant.
    User Preferences:
    - Pax: ${prefs.pax} (${prefs.hasChildren ? "${prefs.childrenCount} kids" : "No kids"})
    - Elderly: ${prefs.hasElderly}
    - Vibe: ${prefs.tripVibe.join(", ")}
    - Budget: ${prefs.budget}
    - Stay: ${prefs.accommodation}
    - Rules: $rules

    $dietaryRule

    IMPORTANT:
    If the user asks for a trip plan, you MUST reply with valid JSON format only.
    
    JSON Structure:
    {
      "is_itinerary": true,
      "trip_name": "Short Trip Title",
      "duration": "e.g. 3 Days",
      "country": "Country Name",
      "continent": "Continent Name",
      "tags": ["Family", "Nature", "Halal"],
      "summary": "A short 2-sentence summary of the trip enthusiasm.",
      "days": [
        {
          "day": 1,
          "theme": "City Highlights",
          "activities": [
            {"time": "09:00 AM", "title": "Start at X", "desc": "Description...", "geo": "Place Name"},
            {"time": "10:30 AM", "title": "Walk to Y", "desc": "Nearby spot...", "geo": "Place Name"},
            {"time": "Lunch", "title": "Lunch at [Specific Name]", "desc": "Must be specific!", "geo": "Restaurant Name"},
            {"time": "02:00 PM", "title": "Visit Z", "desc": "Description...", "geo": "Place Name"},
            {"time": "04:00 PM", "title": "Coffee at A", "desc": "Description...", "geo": "Place Name"},
            {"time": "Dinner", "title": "Dinner at [Specific Name]", "desc": "Must be specific!", "geo": "Restaurant Name"}
          ]
        }
      ]
    }

    STRICT RULES:
    1. RETURN ONLY RAW JSON. No Markdown.
    2. **FULL DAY RULE**: You MUST schedule activities from **9:00 AM** until at least **9:00 PM**. Do not stop at 4:00 PM.
    3. **DENSITY RULE**: 
       - Morning: 2-3 activities.
       - Afternoon: 2-3 activities.
       - Evening: Dinner + 1 Night Activity (e.g., Night view, Walk, or Market).
    4. **MEAL RULE**: Include specific 'Lunch' and 'Dinner' with real restaurant names.
    5. **TIME LABELS**: Use specific times (e.g., "09:00 AM", "07:00 PM").
    6. Use double quotes for all keys.
    """;

    try {
      List<Map<String, String>> apiMessages = [];
      apiMessages.add({"role": "system", "content": systemPrompt});

      if (previousMessages != null) {
        for (var msg in previousMessages.reversed) {
          apiMessages.add({
            "role": msg.user.id == 'user' ? "user" : "assistant", 
            "content": msg.text,
          });
        }
      }

      apiMessages.add({"role": "user", "content": userMessage});
      
      final response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $_apiKey",
        },
        body: jsonEncode({
          "model": "gpt-4o-mini", 
          "messages": apiMessages,
          "temperature": 0.7,
        }),
      );

      if (response.statusCode != 200) {
        return {"content": "⚠️ OpenAI error (${response.statusCode})."};
      }

      final data = jsonDecode(response.body);
      String contentString = data?['choices']?[0]?['message']?['content'] ?? "";

      contentString = contentString.replaceAll("```json", "").replaceAll("```", "").trim();

      int firstBrace = contentString.indexOf('{');
      int lastBrace = contentString.lastIndexOf('}');

      if (firstBrace != -1 && lastBrace != -1) {
         String jsonString = contentString.substring(firstBrace, lastBrace + 1);
         try {
           return jsonDecode(jsonString) as Map<String, dynamic>;
         } catch (e) {
           print("JSON Parsing Error: $e");
           return {"content": "I made a mistake reading the map! 🗺️ Try again?"};
         }
      }
      return {"is_itinerary": false, "content": contentString};

    } catch (e) {
      return {"content": "⚠️ Network error: $e"};
    }
  }
}