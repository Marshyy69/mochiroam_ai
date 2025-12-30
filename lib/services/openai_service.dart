// lib/services/openai_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/travel_preferences.dart';

class OpenAIService {
  static final String _apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';

  static Future<Map<String, dynamic>> sendMessage({
    required String userMessage,
    required TravelPreferences prefs,
    required String rules,
  }) async {
    if (_apiKey.isEmpty) {
      print("❌ Error: API Key is missing.");
      return {"content": "⚠️ OpenAI API key not configured."};
    }

    // ✅ FIX IS HERE: Make sure this line is exactly like this:
    final uri = Uri.parse("https://api.openai.com/v1/chat/completions");

          // 🔥 NEW "STRICT FORMAT" PROMPT
          final systemPrompt = """
      You are Mochi AI, a friendly travel assistant.
      User Preferences:
      - Pax: ${prefs.pax}
      - Children: ${prefs.hasChildren}
      - Elderly: ${prefs.hasElderly}
      - Rules: $rules

      IMPORTANT:
      If the user asks for a trip plan, you MUST reply with valid JSON format only.
      Structure:
      {
        "is_itinerary": true,
        "trip_name": "Trip Title",
        "duration": "e.g. 5 Days",
        "content": "..."
      }

      For the 'content' field, you MUST use the following format exactly. Do not write long paragraphs. Use emojis and bold text (*).

      FORMAT TEMPLATE:
# 🇯🇵 Trip Title
(Short 1-sentence intro)

**Day 1 - Title of Day** <-- Uses ** for Bold
**Morning**
• Activity 1 (with detail)
• Activity 2

*Afternoon*
• Activity 1
• Activity 2

*Evening*
• Dinner suggestion
• Night activity

**Day 2 - Title of Day**
      ... (repeat for all days)
      ...

      If it is just a normal chat, reply with:
      {
        "is_itinerary": false,
        "content": "Your friendly response..."
      }
      """;

    try {
      print("📨 Sending request to OpenAI...");
      
      final response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $_apiKey",
        },
        body: jsonEncode({
          "model": "gpt-4o-mini",
          "messages": [
            {"role": "system", "content": systemPrompt},
            {"role": "user", "content": userMessage}
          ],
          "temperature": 0.7,
        }),
      );

      print("📩 Response Status: ${response.statusCode}");
      
      if (response.statusCode != 200) {
        print("❌ API Error: ${response.body}");
        return {"content": "⚠️ OpenAI error (${response.statusCode}). Check console."};
      }

      final data = jsonDecode(response.body);
      String contentString = data?['choices']?[0]?['message']?['content'] ?? "";

      if (contentString.isEmpty) {
        return {"content": "⚠️ I couldn’t generate a response. Try again."};
      }

      print("📦 Raw Content from AI: $contentString");

      contentString = contentString.replaceAll("```json", "").replaceAll("```", "").trim();

      try {
        return jsonDecode(contentString) as Map<String, dynamic>;
      } catch (e) {
        print("⚠️ Parsing failed, returning as plain text. Error: $e");
        return {
          "is_itinerary": false,
          "content": contentString
        };
      }
    } catch (e) {
      print("❌ Network Exception: $e");
      return {"content": "⚠️ Network error: $e"};
    }
  }
}