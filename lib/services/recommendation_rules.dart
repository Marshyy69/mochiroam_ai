import '../models/travel_preferences.dart';

class RecommendationRules {
  /// Builds a concise, structured rules string from user preferences.
  /// Every preference category is represented so Gemini strictly follows them.
  static String build(TravelPreferences prefs) {
    final rules = <String>[];

    // ── 1. GROUP TYPE ──────────────────────────────────────────────
    final groupType = _detectGroupType(prefs);
    rules.add("GROUP: $groupType");

    if (prefs.pax == 1) {
      rules.add("- Solo traveler: suggest safe, social spots and solo-friendly dining.");
    } else if (prefs.pax == 2 && !prefs.hasChildren && !prefs.hasElderly) {
      rules.add("- Couple trip: include romantic views, cozy restaurants, scenic walks.");
    } else if (prefs.pax >= 3) {
      rules.add("- Group of ${prefs.pax}: suggest group-friendly activities and shared dining.");
    }

    // ── 2. CHILDREN ────────────────────────────────────────────────
    if (prefs.hasChildren) {
      rules.add("CHILDREN: ${prefs.childrenCount} kids (Ages: ${prefs.childrenAgeRange}).");
      rules.add("- Activities MUST be kid-friendly (parks, interactive museums, playgrounds).");
      rules.add("- Avoid long hikes, strict-silence venues, nightlife.");
      rules.add("- Schedule rest/snack breaks between activities.");
      rules.add("- PACE: Relaxed — max 4-5 activities per day.");
    }

    // ── 3. ELDERLY ─────────────────────────────────────────────────
    if (prefs.hasElderly) {
      rules.add("ELDERLY TRAVELERS present.");
      rules.add("- Minimize walking, avoid steep climbs or rough terrain.");
      rules.add("- Prefer elevators/escalators, ground-floor access.");
      rules.add("- Transport: taxis or direct transfers, no long walks between stops.");
      rules.add("- PACE: Gentle — max 4 activities per day.");
    }

    // ── 4. HALAL ───────────────────────────────────────────────────
    if (prefs.isHalal) {
      rules.add("HALAL: STRICT YES.");
      rules.add("- ALL food MUST be Halal-certified or Muslim-friendly.");
      rules.add("- FORBIDDEN: pork, babi, bak kut teh, char siew, beer, wine, bars, pubs, izakaya.");
      rules.add("- If Halal restaurant data is provided, USE THEM.");
      rules.add("- Avoid alcohol-focused nightlife.");
    }

    // ── 5. BUDGET ──────────────────────────────────────────────────
    rules.add("BUDGET: ${prefs.budget}.");
    if (prefs.budget.contains("Budget")) {
      rules.add("- Focus on free attractions, street food, public transport, markets.");
      rules.add("- Avoid expensive tickets unless iconic/famous.");
      rules.add("- Suggest affordable local eateries, hawker centres, food courts.");
    } else if (prefs.budget.contains("Luxury")) {
      rules.add("- Suggest fine dining, private tours, premium experiences.");
      rules.add("- Include high-end restaurants, spas, VIP access.");
      rules.add("- Transport: private car, first-class train where applicable.");
    } else {
      rules.add("- Mix of free and paid attractions.");
      rules.add("- Mid-range restaurants and cafes.");
    }

    // ── 6. ACCOMMODATION ───────────────────────────────────────────
    rules.add("ACCOMMODATION: ${prefs.accommodation}.");
    if (prefs.accommodation.contains("Homestay") || prefs.accommodation.contains("Airbnb")) {
      rules.add("- Suggest activities in local neighborhoods, residential areas.");
      rules.add("- Include local markets and community experiences.");
    } else if (prefs.accommodation.contains("Hostel") || prefs.accommodation.contains("Dorm")) {
      rules.add("- Include backpacker-friendly areas, affordable zones.");
      rules.add("- Suggest social activities, group tours, pub crawls (if not Halal).");
    } else if (prefs.accommodation.contains("Resort")) {
      rules.add("- Include resort/beach leisure, spa, pool time in the schedule.");
      rules.add("- Keep some half-days free for in-resort relaxation.");
    }

    // ── 7. TRIP VIBES / INTERESTS ──────────────────────────────────
    if (prefs.tripVibe.isNotEmpty) {
      rules.add("INTERESTS: ${prefs.tripVibe.join(', ')}.");
      for (var vibe in prefs.tripVibe) {
        final v = vibe.toLowerCase();
        if (v.contains("nature")) {
          rules.add("- Prioritize parks, gardens, scenic viewpoints, nature reserves.");
        } else if (v.contains("adventure")) {
          rules.add("- Include hiking, water sports, zip-lining, active experiences.");
        } else if (v.contains("shopping")) {
          rules.add("- Include malls, markets, souvenir shops, outlet stores.");
        } else if (v.contains("culture") || v.contains("history")) {
          rules.add("- Focus on museums, heritage sites, temples, historical landmarks.");
        } else if (v.contains("foodie") || v.contains("food")) {
          rules.add("- Emphasize food tours, famous local dishes, food markets, cooking classes.");
        } else if (v.contains("relax")) {
          rules.add("- Include spas, onsen, beach lounging, slow-paced scenic spots.");
          rules.add("- PACE: Relaxed — fewer activities, more leisure time.");
        } else if (v.contains("city")) {
          rules.add("- Include city landmarks, skyline views, nightlife, urban exploration.");
        } else if (v.contains("photo")) {
          rules.add("- Include Instagrammable spots, sunrise/sunset viewpoints, aesthetic cafes.");
        }
      }
    }

    // ── 8. DEFAULT PACE ────────────────────────────────────────────
    if (!prefs.hasChildren && !prefs.hasElderly &&
        !prefs.tripVibe.any((v) => v.toLowerCase().contains("relax"))) {
      rules.add("PACE: Standard — 5-6 activities per day.");
    }

    return rules.join("\n");
  }

  /// Detects group type label for the prompt.
  static String _detectGroupType(TravelPreferences prefs) {
    if (prefs.hasChildren) return "Family with children";
    if (prefs.hasElderly) return "Group with elderly";
    if (prefs.pax == 1) return "Solo traveler";
    if (prefs.pax == 2) return "Couple";
    return "Group of ${prefs.pax}";
  }
}