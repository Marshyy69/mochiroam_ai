import '../models/travel_preferences.dart';

class RecommendationRules {
  /// Builds a detailed, structured rules string from user preferences.
  /// Every preference category is represented so Gemini strictly follows them.
  static String build(TravelPreferences prefs) {
    final rules = <String>[];

    // ── 1. GROUP TYPE ──────────────────────────────────────────────
    final groupType = _detectGroupType(prefs);
    rules.add("👥 GROUP: $groupType (${prefs.pax} travelers)");

    if (prefs.pax == 1) {
      rules.add("- Solo traveler: suggest safe, social spots and solo-friendly dining.");
      rules.add("- Include co-working cafes, walking tours, and social hostels/meetups.");
      rules.add("- Recommend well-lit evening areas for solo exploration.");
    } else if (prefs.pax == 2 && !prefs.hasChildren && !prefs.hasElderly) {
      rules.add("- Couple trip: include romantic views, cozy restaurants, scenic walks.");
      rules.add("- Suggest couples experiences: sunset cruises, wine/tea tastings, spa duos.");
      rules.add("- Prioritize intimate dining over large group restaurants.");
    } else if (prefs.pax >= 3) {
      rules.add("- Group of ${prefs.pax}: suggest group-friendly activities and shared dining.");
      rules.add("- Include activities everyone can enjoy together (group tours, cooking classes).");
      rules.add("- Recommend restaurants with large tables and group-friendly menus.");
    }

    // ── 2. CHILDREN ────────────────────────────────────────────────
    if (prefs.hasChildren) {
      rules.add("👶 CHILDREN: ${prefs.childrenCount} kids (Ages: ${prefs.childrenAgeRange}).");
      rules.add("- Activities MUST be kid-friendly: parks, interactive museums, playgrounds, aquariums, zoos.");
      rules.add("- Avoid: long hikes (>1 hour), strict-silence venues, nightlife, extreme sports.");
      rules.add("- Schedule rest/snack breaks between activities (every 2-3 hours).");
      rules.add("- Include at least 1 playground/fun zone per day.");
      rules.add("- Choose restaurants with kids menus or family-friendly atmosphere.");
      rules.add("- PACE: Relaxed — max 5 activities per day with buffer time.");
    }

    // ── 3. ELDERLY ─────────────────────────────────────────────────
    if (prefs.hasElderly) {
      rules.add("👴 ELDERLY TRAVELERS present.");
      rules.add("- Minimize walking distance between stops (max 10-15 min walks).");
      rules.add("- Avoid steep climbs, rough terrain, stairs without elevators.");
      rules.add("- Prefer air-conditioned venues during midday heat.");
      rules.add("- Transport: taxis or direct transfers, no long walks between stops.");
      rules.add("- Include comfortable seating areas and rest spots.");
      rules.add("- PACE: Gentle — max 5 activities per day with longer breaks.");
    }

    // ── 4. HALAL ───────────────────────────────────────────────────
    if (prefs.isHalal) {
      rules.add("🕌 HALAL: STRICT YES — NON-NEGOTIABLE.");
      rules.add("- ALL food MUST be Halal-certified or verified Muslim-friendly.");
      rules.add("- ABSOLUTELY FORBIDDEN: pork, babi, bak kut teh, char siew, lard, gelatin (non-halal), beer, wine, sake, bars, pubs, izakaya.");
      rules.add("- If Halal restaurant data is provided, USE THEM as primary food recommendations.");
      rules.add("- Mention 'Halal-certified' or 'Muslim-friendly' explicitly in all food descriptions.");
      rules.add("- Avoid alcohol-focused venues entirely (wine bars, craft beer spots, izakayas).");
      rules.add("- If in a non-Muslim country, suggest international chains known for Halal options or verified Halal restaurants.");
      rules.add("- Consider prayer times: suggest nearby mosques or prayer rooms for Dhuhr and Asr.");
    }

    // ── 5. BUDGET ──────────────────────────────────────────────────
    rules.add("💰 BUDGET: ${prefs.budget}.");
    if (prefs.budget.contains("Budget")) {
      rules.add("- Focus on FREE attractions: parks, temples, public beaches, street art, city walks.");
      rules.add("- Food: street food, hawker centres, food courts, local warungs/kedai makan.");
      rules.add("- Transport: public transit (MRT, bus), walking. Avoid taxis unless necessary.");
      rules.add("- Skip expensive tickets unless the attraction is iconic/must-see.");
      rules.add("- Mention approximate costs so the traveler can budget accordingly.");
    } else if (prefs.budget.contains("Luxury")) {
      rules.add("- Suggest fine dining, Michelin-starred or award-winning restaurants.");
      rules.add("- Include private tours, VIP access, premium experiences (helicopter rides, private boat).");
      rules.add("- Recommend luxury spas, first-class lounges, high-end shopping districts.");
      rules.add("- Transport: private car, first-class train, premium taxi services.");
      rules.add("- Accommodation experiences: rooftop bars, pool access, concierge recommendations.");
    } else {
      rules.add("- Smart mix of free and paid attractions (aim for 60% free, 40% paid).");
      rules.add("- Mid-range restaurants and trendy cafes with good value.");
      rules.add("- Mix public transit with occasional taxi for convenience.");
      rules.add("- Include some splurge-worthy experiences alongside budget-friendly options.");
    }

    // ── 6. ACCOMMODATION ───────────────────────────────────────────
    rules.add("🏨 ACCOMMODATION: ${prefs.accommodation}.");
    if (prefs.accommodation.contains("Homestay") || prefs.accommodation.contains("Airbnb")) {
      rules.add("- Suggest activities in local neighborhoods, residential areas.");
      rules.add("- Include local markets, community experiences, neighborhood walks.");
      rules.add("- Recommend cooking local breakfast or grabbing from nearby street vendors.");
    } else if (prefs.accommodation.contains("Hostel") || prefs.accommodation.contains("Dorm")) {
      rules.add("- Include backpacker-friendly areas, affordable zones.");
      rules.add("- Suggest social activities: free walking tours, group day trips, common-area meetups.");
      if (!prefs.isHalal) rules.add("- Consider pub crawls, bar hopping areas for nightlife.");
    } else if (prefs.accommodation.contains("Resort")) {
      rules.add("- Include resort/beach leisure, spa, pool time in the schedule.");
      rules.add("- Keep some half-days free for in-resort relaxation (don't over-schedule).");
      rules.add("- Suggest resort dining options alongside external restaurants.");
    }

    // ── 7. TRIP VIBES / INTERESTS ──────────────────────────────────
    if (prefs.tripVibe.isNotEmpty) {
      final vibeNames = prefs.tripVibe.map((v) => v.split(' ').first).join(', ');
      rules.add("🎯 SELECTED INTERESTS: ${prefs.tripVibe.join(', ')}.");
      rules.add("⚡ HARD RULE: At least 80% of non-food activities MUST directly match these interests: $vibeNames.");
      rules.add("⚡ DO NOT add generic sightseeing activities that don't align with the selected interests.");
      rules.add("⚡ Day themes MUST reference the selected interests (e.g., if Shopping → 'Retail Therapy at [Area]').");
      for (var vibe in prefs.tripVibe) {
        final v = vibe.toLowerCase();
        if (v.contains("nature")) {
          rules.add("  🌿 NATURE selected → Fill activity slots with: parks, botanical gardens, scenic viewpoints, nature reserves, waterfalls, hiking trails, eco-tours, wildlife sanctuaries.");
          rules.add("    ❌ DON'T: suggest malls, museums, or urban attractions unless it's a nature-themed one.");
        } else if (v.contains("adventure")) {
          rules.add("  🎢 ADVENTURE selected → Fill activity slots with: hiking, water sports, zip-lining, rock climbing, bungee, ATV rides, kayaking, snorkeling, paragliding, canyoning.");
          rules.add("    ❌ DON'T: suggest passive/relaxing activities or generic city tours.");
        } else if (v.contains("shopping")) {
          rules.add("  🛍️ SHOPPING selected → Fill activity slots with: malls, outlet stores, local markets, night bazaars, fashion streets, souvenir shops, artisan boutiques, duty-free stores, vintage shops, designer districts.");
          rules.add("    ❌ DON'T: suggest museums, temples, or nature hikes. The user wants to SHOP.");
          rules.add("    → Include different shopping categories each day: fashion, electronics, local crafts, luxury brands, street markets.");
          rules.add("    → Evening activities should be night markets or shopping malls that open late.");
        } else if (v.contains("culture") || v.contains("history")) {
          rules.add("  🏛️ CULTURE selected → Fill activity slots with: museums, heritage sites, temples, historical landmarks, art galleries, traditional performances, historical districts, ancient ruins, cultural workshops.");
          rules.add("    ❌ DON'T: suggest shopping malls or adventure sports.");
        } else if (v.contains("foodie") || v.contains("food")) {
          rules.add("  🍜 FOODIE selected → Every single meal is a destination experience. PLUS add: food tours, cooking classes, street food crawls, food markets, bakery visits, local snack tastings between meals.");
          rules.add("    → Name SPECIFIC dishes to try at each restaurant.");
          rules.add("    ❌ DON'T: treat meals as afterthoughts. Food IS the main activity.");
        } else if (v.contains("relax")) {
          rules.add("  🧘 RELAXATION selected → Fill activity slots with: spas, massage parlors, onsen/hot springs, beach lounging, scenic cafes, yoga sessions, meditation retreats, sunset viewing.");
          rules.add("    → PACE: Max 5 activities per day. Include 1-2 hour rest gaps.");
          rules.add("    ❌ DON'T: pack the schedule tight or suggest adrenaline activities.");
        } else if (v.contains("city")) {
          rules.add("  🏙️ CITY LIFE selected → Fill activity slots with: city landmarks, skyline views, observation decks, urban walks, street art tours, trendy neighborhoods, rooftop bars/cafes, night city lights.");
          rules.add("    ❌ DON'T: suggest rural nature hikes or beach activities.");
        } else if (v.contains("photo")) {
          rules.add("  📸 PHOTOGRAPHY selected → Fill activity slots with: Instagrammable spots, sunrise/sunset viewpoints, aesthetic cafes, murals, scenic overlooks, rooftop views, colorful streets, iconic landmarks for photos.");
          rules.add("    → Mention best time of day and lighting conditions for each spot.");
          rules.add("    ❌ DON'T: suggest places with no visual interest.");
        } else if (v.contains("nightlife")) {
          if (!prefs.isHalal) {
            rules.add("  🌙 NIGHTLIFE selected → Include: rooftop bars, live music venues, night markets, club districts, jazz bars, speakeasies.");
          } else {
            rules.add("  🌙 NIGHTLIFE selected (Halal) → Include: night markets, dessert cafes, shisha lounges, moonlit walks, cultural night shows, late-night food streets.");
          }
        } else if (v.contains("wellness") || v.contains("health")) {
          rules.add("  💆 WELLNESS selected → Fill activity slots with: spas, yoga studios, health restaurants, meditation centers, thermal baths, detox juice bars, organic cafes.");
        } else if (v.contains("beach")) {
          rules.add("  🏖️ BEACH selected → Fill activity slots with: beach swimming, snorkeling, island hopping, beach cafes, sunset walks, water sports, coastal trails.");
        }
      }
      rules.add("  ✅ VERIFY: Before finalizing, check that EVERY non-food activity slot directly relates to: $vibeNames. If it doesn't, replace it with one that does.");
    }

    // ── 8. DEFAULT PACE ────────────────────────────────────────────
    if (!prefs.hasChildren && !prefs.hasElderly &&
        !prefs.tripVibe.any((v) => v.toLowerCase().contains("relax"))) {
      rules.add("⏱️ PACE: Standard — 10-12 activities per day, spaced 1-1.5 hours apart, NO large time gaps.");
    }

    // ── 9. STRICT FOOD LIMIT ───────────────────────────────────────
    rules.add("🍔 FOOD/CAFE LIMIT: Suggest ONLY 2 or 3 specific restaurants/cafes per day in total.");
    rules.add("- Typically: 1 Lunch restaurant, 1 Dinner restaurant, and at most 1 Cafe break.");
    rules.add("- Breakfast MUST be a generic note (e.g., 'Breakfast at hotel' or 'Quick grab-and-go snack') and must NOT recommend a specific named restaurant or cafe.");
    rules.add("- All other activities must be attractions, activities, shopping, culture, nature, or sightseeing, NOT food/cafe venues.");

    // ── 10. CURRENCY ───────────────────────────────────────────────
    final currencyCode = prefs.currency.split(' ').first;
    final currencySymbol = {
      'MYR': 'RM', 'SGD': 'S\$', 'IDR': 'Rp', 'USD': '\$',
    }[currencyCode] ?? '\$';
    final currencyLabel = {
      'MYR': 'Malaysian Ringgit (RM)',
      'SGD': 'Singapore Dollar (S\$)',
      'IDR': 'Indonesian Rupiah (Rp)',
      'USD': 'US Dollar (\$)',
    }[currencyCode] ?? 'US Dollar (\$)';
    rules.add("💱 CURRENCY: $currencyLabel.");
    rules.add("- ALL cost estimates in activity \"cost\" fields MUST use $currencySymbol symbol.");
    rules.add("- Transport cost hints should also use $currencySymbol.");
    rules.add("- Do NOT use \$ or USD unless the user's currency is USD.");

    // ── 11. MANDATORY QUALITY REMINDERS ────────────────────────────
    rules.add("");
    rules.add("⚠️ MANDATORY QUALITY CHECKS:");
    rules.add("- Every activity description MUST be 2-3 detailed sentences (NOT generic one-liners).");
    rules.add("- Every activity MUST include category, tip, cost, and transport fields.");
    rules.add("- Each day MUST have 10-12 activities (or 8 if Relaxation/Children/Elderly). NO time gaps longer than 1.5 hours.");
    rules.add("- Suggest ONLY 2 or 3 named restaurant/cafe recommendations per day. Breakfast must NOT be a named restaurant/cafe.");
    rules.add("- ALL costs MUST be in $currencyLabel — never default to USD.");
    rules.add("- Day themes should be creative and descriptive (NOT just 'Day 1', 'Day 2').");
    rules.add("- The trip summary (full_content) MUST be 3-4 engaging sentences.");
    rules.add("- Include 5-7 tags that accurately reflect the destinations, activities, and vibes.");

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