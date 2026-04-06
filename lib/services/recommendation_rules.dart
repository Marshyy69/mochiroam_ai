import '../models/travel_preferences.dart';

class RecommendationRules {
  static String build(TravelPreferences prefs) {
    final rules = <String>[];

    // 1. 🕌 HALAL LOGIC (The most important rule)
    if (prefs.isHalal) {
      rules.add("CRITICAL: All food suggestions MUST be Halal-certified or Muslim-friendly.");
      rules.add("Avoid recommending bars, pubs, or nightlife focused on alcohol.");
      rules.add("If specific Halal restaurants are provided in the context, YOU MUST USE THEM.");
    }

    // 2. 💰 BUDGET LOGIC
    if (prefs.budget.contains("Budget")) {
      rules.add("Focus on free attractions, street food, and public transport.");
      rules.add("Avoid expensive ticketed entry fees unless famous.");
    } else if (prefs.budget.contains("Luxury")) {
      rules.add("Suggest fine dining, private tours, and premium comfort.");
    }

    // 3. 👨‍👩‍👧‍👦 COMPANION LOGIC
    if (prefs.hasChildren) {
      rules.add("Ensure activities are kid-friendly (parks, interactive museums).");
      rules.add("Avoid long hiking trails or places with strict silence rules.");
      rules.add("Pacing: Allow breaks for rest/snacks.");
    } else if (prefs.hasElderly) {
      rules.add("CRITICAL: Minimal walking. Suggest elevators/escalators.");
      rules.add("Avoid steep climbs or rough terrain.");
      rules.add("Transport: Suggest taxis or direct transfers.");
    } else if (prefs.pax == 1) {
      rules.add("Solo Traveler Mode: Suggest safe, social public places.");
      rules.add("Include tips for solo dining or joining group tours.");
    }

    // 4. ✨ VIBE LOGIC
    for (var vibe in prefs.tripVibe) {
      if (vibe.contains("Nature")) rules.add("Prioritize parks, gardens, and scenic views.");
      if (vibe.contains("Adventure")) rules.add("Include active experiences (hiking, sports, thrill).");
      if (vibe.contains("Shopping")) rules.add("Include malls, markets, and souvenir hunting.");
      if (vibe.contains("History")) rules.add("Focus on museums, heritage sites, and culture.");
    }

    return rules.join("\n");
  }
}