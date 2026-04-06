import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:google_generative_ai/google_generative_ai.dart'; // ✅ NEW IMPORT

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

    // 1. SETUP RULES & CONTEXT (Same as your old logic)
    String smartRules = RecommendationRules.build(prefs);
    String realDataContext = "";
    String negativeFilter = "";

    bool isPlanningQuery = userMessage.toLowerCase().contains("trip") || 
                           userMessage.toLowerCase().contains("plan") ||
                           userMessage.toLowerCase().contains("itinerary");

    if (prefs.isHalal) {
       negativeFilter = """
       CRITICAL HALAL ENFORCEMENT:
       - STRICTLY FORBIDDEN: Babi, Pork, Pig, Bak Kut Teh, Char Siew, Wine, Beer, Bars, Pubs.
       - FORBIDDEN REPETITION: Do NOT suggest 'Wagyu' or 'Yakiniku' more than ONCE per trip.
       """;
    }

    if (isPlanningQuery) {
         print("🔍 Fetching Real Restaurants (Halal Mode: ${prefs.isHalal})");
         String places = await SerpApiService.findPlaces(userMessage, isHalal: prefs.isHalal);
         
         if (places.isNotEmpty) {
           realDataContext = """
           REAL-TIME GOOGLE MAPS DATA (Top Rated Places):
           $places
           
           INSTRUCTIONS:
           1. Use these EXACT restaurants for Lunch/Dinner matching the location.
           2. DIVERSITY: Mix up the cuisines (Ramen, Sushi, etc).
           3. If the user is Halal, ONLY use the Halal options provided.
           4. If the user is NOT Halal, suggest the popular spots provided.
           """;
         }
    }

  // 2. SYSTEM PROMPT (With JSON Blueprint Restored)
    String systemPrompt = """
    You are Mochi, a smart AI travel companion.
    
    USER PREFERENCES:
    $smartRules
    $negativeFilter

    REAL-TIME DATA:
    $realDataContext

    YOUR GOAL:
    Return a strict JSON object.

    ### CRITICAL DENSITY RULES:
    You MUST provide at least 5-6 activities PER DAY.
    Structure every day exactly like this:
    1. Morning Activity
    2. Late Morning Activity
    3. Lunch (Must be a Restaurant)
    4. Afternoon Activity
    5. Dinner (Must be a Restaurant)
    6. Night Activity

    ### CRITICAL JSON STRUCTURE (COPY THIS EXACTLY):
    {
      "trip_name": "Trip Title",
      "country": "Country",
      "duration": "X Days",
      "full_content": "Summary...",
      "cover_image": "http...",
      "tags": ["Tag1", "Tag2"],
      "is_halal": ${prefs.isHalal},
      "trip_data": {
        "days": [
           {
             "day": 1,
             "theme": "Theme Name",
             "activities": [
                { "time": "09:00 AM", "title": "Activity 1", "desc": "Desc" },
                { "time": "11:00 AM", "title": "Activity 2", "desc": "Desc" },
                { "time": "Lunch", "title": "Lunch at [Name]", "desc": "Desc." }, 
                { "time": "02:00 PM", "title": "Activity 3", "desc": "Desc" },
                { "time": "Dinner", "title": "Dinner at [Name]", "desc": "Desc." },
                { "time": "08:00 PM", "title": "Activity 4", "desc": "Desc" }
             ]
           }
        ]
      }
    }
    """;

    // 3. INITIALIZE GEMINI MODEL
    final model = GenerativeModel(
      model: 'gemini-2.5-flash', // Lightning fast, huge context window
      apiKey: _apiKey,
      systemInstruction: Content.system(systemPrompt), // ✅ Native system prompt support!
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json', // ✅ Forces pure JSON output
        temperature: 0.7,
      ),
    );

    // 4. MAP DASHCHAT HISTORY TO GEMINI HISTORY
    List<Content> chatHistory = [];
    if (previousMessages != null) {
      // Take the last 4 messages and reverse them to chronological order
      for (var msg in previousMessages.reversed.take(4)) {
        // DashChat uses 'user' for current user. Gemini uses 'user' and 'model'
        final role = msg.user.id == 'user' ? 'user' : 'model';
        chatHistory.add(Content(role, [TextPart(msg.text)]));
      }
    }

    try {
      // 5. START CHAT & SEND MESSAGE
      final chat = model.startChat(history: chatHistory);
      final response = await chat.sendMessage(Content.text(userMessage));
      
      final String contentString = response.text ?? "";

      // 6. PARSE JSON (Look how clean this is now!)
      try {
        Map<String, dynamic> tripData = jsonDecode(contentString) as Map<String, dynamic>;
        
        // 🚓 HALAL POLICE (Still active!)
        if (prefs.isHalal) {
          _enforceHalal(tripData);
        }
        
        return tripData; 
      } catch (e) {
        print("JSON Parsing Error: $e");
        return {"content": "I couldn't format that properly. Could you ask me again?"};
      }

    } catch (e) {
      return {"content": "Error connecting to Mochi Brain: $e"};
    }
  }

  // 🚓 THE HALAL POLICE (Unchanged)
  static void _enforceHalal(Map<String, dynamic> tripData) {
    final List<String> haramWords = [
      "babi", "pork", "pig", "bak kut teh", "char siew", "beer", "wine", "bar ", "pub ", "izakaya"
    ];

    List<dynamic> days = [];
    if (tripData['trip_data'] != null && tripData['trip_data']['days'] != null) {
      days = tripData['trip_data']['days'];
    } else if (tripData['days'] != null) {
      days = tripData['days'];
    }

    for (var day in days) {
      List<dynamic> activities = day['activities'] ?? [];
      for (var act in activities) {
        String title = act['title'].toString().toLowerCase();
        String desc = act['desc'].toString().toLowerCase();

        bool isHaram = haramWords.any((word) => title.contains(word) || desc.contains(word));

        if (isHaram) {
          print("🚨 HALAL POLICE: Censored '${act['title']}'");
          act['title'] = "Local Halal Delight";
          act['desc'] = "A verified Muslim-friendly restaurant nearby.";
        }
      }
    }
  }
}