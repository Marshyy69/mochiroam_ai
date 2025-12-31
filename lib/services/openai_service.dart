import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/travel_preferences.dart';
import 'serp_api_service.dart'; 

class OpenAIService {
  static final String _apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';

  static Future<Map<String, dynamic>> sendMessage({
    required String userMessage,
    required TravelPreferences prefs, // ✅ Only this is needed now
    required String rules,
  }) async {
    if (_apiKey.isEmpty) {
      print("❌ Error: API Key is missing.");
      return {"content": "⚠️ OpenAI API key not configured."};
    }

    final uri = Uri.parse("https://api.openai.com/v1/chat/completions");

    // ---------------------------------------------------------
    // 1. HALAL & SERPAPI LOGIC
    // ---------------------------------------------------------
    String dietaryRule = "";
    String realData = "";

    // ✅ CHECK INSIDE PREFS
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
- PRIORITIZE using the following verified places in your itinerary if they match the location:
$realData
- If the suggested places don't fit the schedule, find other known Halal options but clearly label them.
""";
    }

 // ---------------------------------------------------------
    // 2. SYSTEM PROMPT (Updated for Bolding)
    // ---------------------------------------------------------
    final systemPrompt = """
You are Mochi AI, a friendly travel assistant.
User Preferences:
- Pax: ${prefs.pax}
- Children: ${prefs.hasChildren}
- Elderly: ${prefs.hasElderly}
- Rules: $rules

$dietaryRule

IMPORTANT:
If the user asks for a trip plan, you MUST reply with valid JSON format only.
Structure:
{
  "is_itinerary": true,
  "trip_name": "Trip Title",
  "duration": "e.g. 5 Days",
  "content": "..."
}

🎨 FORMATTING & STYLE RULES:
1. **Bold Time Headers**: Always add an emoji (e.g., **Morning ☀️**, **Evening 🌙**).
2. **Bold Place Names**: Use **Bold** for specific places/restaurants.
3. **Emoji Overload**: Add a relevant emoji to EVERY bullet point (e.g., 🍜 for food, ⛩️ for temples, 📸 for views).
4. **Tone**: Be enthusiastic and cute!

FORMAT TEMPLATE:
# 🇯🇵 Trip Title
(Short 1-sentence intro)

**Day 1 - Title of Day**

**Morning**
• Visit **Place Name 1** - Short description.
• Walk around **Place Name 2**.
• Brunch at **Restaurant Name** (Halal/Vegan if requested).

**Afternoon**
• Explore **Landmark Name**.
• Activity at **Place Name**.

**Evening**
• Dinner at **Restaurant Name**.
• Night view at **Place Name**.

**Day 2 - Title of Day**
... (repeat)

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

      if (response.statusCode != 200) {
        print("❌ API Error: ${response.body}");
        return {"content": "⚠️ OpenAI error (${response.statusCode})."};
      }

      final data = jsonDecode(response.body);
      String contentString = data?['choices']?[0]?['message']?['content'] ?? "";

      contentString = contentString.replaceAll("```json", "").replaceAll("```", "").trim();

      try {
        return jsonDecode(contentString) as Map<String, dynamic>;
      } catch (e) {
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