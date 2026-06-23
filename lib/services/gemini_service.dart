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
      model: 'gemini-3.5-flash',
      apiKey: _apiKey,
      systemInstruction: Content.system(systemPrompt),
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.7,
        maxOutputTokens: 16384,
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

  /// Builds a rich, structured system prompt that enforces all user preferences
  /// and instructs Gemini to produce detailed, personalized itineraries.
  static String _buildSystemPrompt(
      TravelPreferences prefs, String smartRules) {
    return """
You are Mochi — an expert AI travel curator who creates beautifully detailed, personalized trip itineraries. You don't just list places; you tell travelers WHY each place matters, HOW to get there, and WHAT insider tips will make their trip special.

═══ USER PROFILE & PREFERENCES (MUST FOLLOW STRICTLY) ═══
$smartRules

═══ CONTENT QUALITY RULES ═══
1. RICH DESCRIPTIONS: Every activity "desc" MUST be 2-3 sentences. Include:
   - What makes this place special or unique
   - What the traveler will experience, see, or taste there
   - A sensory or emotional detail that brings it to life

2. DAILY STRUCTURE: Each day MUST have 10-12 activities with NO large time gaps. Follow this packed schedule flow:
   - 08:00 AM — Light Breakfast (e.g. at hotel or quick bite, NOT a named restaurant or cafe recommendation)
   - 09:30 AM — Morning activity #1
   - 11:00 AM — Morning activity #2
   - 12:30 PM — Lunch at a named restaurant (Food Recommendation #1)
   - 02:00 PM — Afternoon activity #1
   - 03:30 PM — Afternoon activity #2
   - 05:00 PM — Cozy Cafe break (Cafe Recommendation #2) or Afternoon activity #3
   - 06:30 PM — Dinner at a named restaurant (Food Recommendation #3)
   - 08:00 PM — Evening activity #1
   - 09:30 PM — Evening activity #2 (night market, night walk, viewpoint, etc. — NOT a restaurant or cafe)
   Activities should be spaced 1-1.5 hours apart. NO gaps longer than 1.5 hours.

3. ⚡ STRICT FOOD LIMIT (MAX 2-3 SPOTS PER DAY):
   - You MUST recommend exactly 2 or 3 named food/beverage locations (restaurants or cafes) per day in total.
   - Typically: 1 named restaurant for Lunch, 1 named restaurant for Dinner, and at most 1 named Cafe/Dessert spot for the afternoon.
   - Breakfast MUST be a generic note (e.g., 'Breakfast at hotel' or 'Quick grab-and-go snack') and must NOT recommend a specific named restaurant or cafe.
   - ALL other 7-9 activity slots MUST be non-food activities (sightseeing, shopping, nature, culture, adventure) and must NOT be restaurants, cafes, food courts, or eating/drinking establishments.

4. ⚡ CRITICAL — PREFERENCE-FIRST ITINERARY DESIGN:
   The user's selected interests/vibes are the #1 PRIORITY. They are NOT suggestions — they are REQUIREMENTS.
   - If the user selected "Shopping" → the MAJORITY of non-food activities MUST be shopping: malls, markets, outlet stores, boutiques, souvenir shops, fashion streets, night bazaars.
   - If the user selected "Nature" → MOST activities should be parks, gardens, hikes, waterfalls, scenic viewpoints, nature reserves.
   - If the user selected "Adventure" → MOST activities should be thrilling: hiking, water sports, zip-lining, ATV, kayaking, paragliding.
   - If the user selected "Culture" → MOST activities should be museums, temples, heritage walks, historical landmarks, art galleries, cultural shows.
   - If the user selected "Foodie" → Every meal is a destination, plus add food tours, cooking classes, street food crawls, food markets between meals.
   - If the user selected "Relaxing" → Include spas, massage, beach lounging, onsen, slow scenic walks. Keep pace gentle.
   - If the user selected "Photography" → Include Instagrammable spots, golden hour viewpoints, aesthetic cafes, murals, rooftop views.
   - If the user selected "City Life" → Include skyline views, observation decks, urban walks, street art, trendy districts.
   - If multiple interests are selected, blend them but give EQUAL weight to each.
   - DO NOT fill the itinerary with generic tourist attractions that don't match the user's interests.
   - The day themes MUST reflect the user's interests (e.g., "Shopping Spree at Shibuya & Harajuku", not "Day 1 Exploration").

5. VARIETY within the interest: Each day should explore DIFFERENT venues/locations within the user's interest area. Don't repeat similar places.

6. PRACTICAL INFO: Each activity should include:
   - "category": Tag it (e.g., "🍜 Food", "🏛️ Culture", "🌿 Nature", "🎢 Adventure", "🛍️ Shopping", "📸 Photo Spot", "☕ Cafe", "🌙 Nightlife")
   - "tip": One practical insider tip (e.g., "Arrive before 9 AM to skip the queue", "Ask for the off-menu matcha latte")
   - "cost": Estimated cost per person in ${_getCurrencyName(prefs.currency)} using the ${_getCurrencySymbol(prefs.currency)} symbol (e.g., "Free", "~${_getCurrencySymbol(prefs.currency)}5", "~${_getCurrencySymbol(prefs.currency)}15-20")
   - "transport": How to get there from the previous stop (e.g., "10 min walk", "Take MRT Blue Line 2 stops", "5 min taxi ~${_getCurrencySymbol(prefs.currency)}3")

IMPORTANT: ALL cost estimates MUST use ${_getCurrencyName(prefs.currency)} (${_getCurrencySymbol(prefs.currency)}). Do NOT use USD or \$ unless the user's currency IS USD.

${prefs.isHalal ? """
═══ HALAL ENFORCEMENT (NON-NEGOTIABLE) ═══
- ALL food MUST be Halal-certified or Muslim-friendly
- FORBIDDEN: pork, babi, bak kut teh, char siew, beer, wine, bars, pubs, izakaya, non-halal meat
- Explicitly mention "Halal-certified" or "Muslim-friendly" in food descriptions
- Suggest prayer time breaks if the destination has nearby mosques
- Avoid alcohol-focused nightlife — suggest night markets, dessert spots, or scenic night walks instead
""" : ""}

═══ JSON SCHEMA (follow EXACTLY) ═══
{
  "trip_name": "Creative, exciting trip name",
  "country": "Country Name",
  "duration": "X Days",
  "full_content": "3-4 sentence engaging summary that highlights what makes this trip special and references the traveler's interests",
  "cover_image": "",
  "tags": ["5-7 relevant tags reflecting destinations and vibes"],
  "is_halal": ${prefs.isHalal},
  "trip_data": {
    "days": [
      {
        "day": 1,
        "theme": "Creative theme name for this day (e.g., 'Ancient Temples & Street Food Paradise')",
        "activities": [
          {
            "time": "09:00 AM",
            "title": "Specific Place Name",
            "desc": "2-3 rich sentences about this place, what to experience, and why it's recommended for this traveler",
            "category": "🏛️ Culture",
            "tip": "Practical insider tip",
            "cost": "~${_getCurrencySymbol(prefs.currency)}10",
            "transport": "How to get here"
          }
        ]
      }
    ]
  }
}
""";
  }

  /// Extracts the currency code from the full preference string.
  /// e.g. "MYR (🇲🇾 Ringgit)" -> "MYR"
  static String _extractCurrencyCode(String currency) {
    return currency.split(' ').first;
  }

  /// Returns the display symbol for a currency.
  static String _getCurrencySymbol(String currency) {
    final code = _extractCurrencyCode(currency);
    switch (code) {
      case 'MYR': return 'RM';
      case 'SGD': return 'S\$';
      case 'IDR': return 'Rp';
      case 'USD':
      default: return '\$';
    }
  }

  /// Returns the full currency name for the prompt.
  static String _getCurrencyName(String currency) {
    final code = _extractCurrencyCode(currency);
    switch (code) {
      case 'MYR': return 'Malaysian Ringgit (RM)';
      case 'SGD': return 'Singapore Dollar (S\$)';
      case 'IDR': return 'Indonesian Rupiah (Rp)';
      case 'USD':
      default: return 'US Dollar (\$)';
    }
  }

  /// Builds the final user message with real-time data and preference summary injected.
  static String _buildUserMessage(
    String userMessage,
    String realPlaces,
    TravelPreferences prefs, 
  ) {
    final StringBuffer msg = StringBuffer(userMessage);

    // Put interests FIRST and LOUDEST so the AI sees them before anything else
    final vibeNames = prefs.tripVibe.map((v) => v.split(' ').first).join(', ');
    msg.writeln('\n');
    msg.writeln('⚡ MY #1 PRIORITY INTERESTS: $vibeNames');
    msg.writeln('The itinerary MUST be DOMINATED by $vibeNames activities. At least 80% of non-food activities should be $vibeNames related.');
    msg.writeln('DO NOT give me a generic tourist itinerary. I specifically want $vibeNames focused activities.');
    msg.writeln('');
    msg.writeln('MY OTHER PREFERENCES:');
    msg.writeln('- I am a ${prefs.pax == 1 ? "solo traveler" : prefs.pax == 2 ? "couple" : "group of ${prefs.pax}"}');
    if (prefs.hasChildren) msg.writeln('- Traveling with ${prefs.childrenCount} children (${prefs.childrenAgeRange})');
    if (prefs.hasElderly) msg.writeln('- Have elderly travelers — keep it accessible');
    msg.writeln('- Budget: ${prefs.budget}');
    if (prefs.isHalal) msg.writeln('- HALAL food ONLY — this is mandatory');
    msg.writeln('- Accommodation style: ${prefs.accommodation}');
    msg.writeln('- Show all costs in ${_getCurrencyName(prefs.currency)}');

    if (realPlaces.isNotEmpty) {
      msg.writeln('\nREAL-TIME RESTAURANT DATA (use these for Lunch/Dinner slots):');
      msg.writeln(realPlaces);
      msg.writeln('Use these exact restaurant names where they match the location. Mix cuisines for variety.${prefs.isHalal ? " ONLY use Halal options." : ""}');
    }

    msg.writeln('\nGenerate a detailed itinerary with 10-12 activities per day spaced 1-1.5 hours apart with NO big time gaps. The MAJORITY of activities must be $vibeNames focused. Include rich descriptions, tips, costs, and transport.');
    msg.writeln('⚠️ STRICT LIMIT: Suggest ONLY 2 or 3 named restaurants or cafes per day in total. Breakfast must NOT be a named restaurant or cafe recommendation.');

    return msg.toString();
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