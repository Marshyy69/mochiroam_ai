import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenAIService {
  static final String _apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';

  static Future<String> sendMessage(String userMessage) async {
    if (_apiKey.isEmpty) {
      return "⚠️ OpenAI API key not configured.";
    }

    final uri = Uri.parse("https://api.openai.com/v1/chat/completions");

    try {
      final response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $_apiKey",
        },
        body: jsonEncode({
          "model": "gpt-4o-mini",
          "messages": [
            {
              "role": "system",
              "content":
                  "You are Mochi AI, a friendly travel planner that creates clear travel itineraries."
            },
            {"role": "user", "content": userMessage}
          ],
          "temperature": 0.7,
        }),
      );

      // ❌ RATE LIMIT OR ERROR
      if (response.statusCode != 200) {
        return "⚠️ OpenAI error (${response.statusCode}). Please try again later.";
      }

      final data = jsonDecode(response.body);

      final content =
          data?['choices']?[0]?['message']?['content'];

      if (content == null || content.toString().isEmpty) {
        return "⚠️ I couldn’t generate a response. Try again.";
      }

      return content.toString();
    } catch (e) {
      return "⚠️ Network error. Please check your connection.";
    }
  }
}
