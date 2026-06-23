class TravelPreferences {
  final int pax;
  final bool hasChildren;
  final int childrenCount;      // 🆕 Miss Siti: How many children?
  final String childrenAgeRange;// 🆕 Miss Siti: Range of age
  final bool hasElderly;
  bool isHalal;
  final List<String> tripVibe;  // 🆕 Miss Siti: Adventure, Nature, etc.
  final String budget;          // 🆕 Miss Siti: Budget per trip
  final String accommodation;   // 🆕 Miss Siti: Homestay vs Hotel
  final String currency;        // Currency preference: USD, MYR, SGD, IDR

  TravelPreferences({
    required this.pax,
    required this.hasChildren,
    this.childrenCount = 0,
    this.childrenAgeRange = "",
    required this.hasElderly,
    required this.isHalal,
    required this.tripVibe,
    required this.budget,
    required this.accommodation,
    this.currency = 'USD',
  });

  // 1. Default Values
  factory TravelPreferences.defaults() {
    return TravelPreferences(
      pax: 1,
      hasChildren: false,
      childrenCount: 0,
      childrenAgeRange: "N/A",
      hasElderly: false,
      isHalal: false,
      tripVibe: ["Balanced"],
      budget: "Standard",
      accommodation: "Hotel",
      currency: "USD",
    );
  }

  // 2. Convert from Supabase/Firestore Map
  // Supports both snake_case (Supabase columns) and camelCase (legacy) keys
  factory TravelPreferences.fromMap(Map<String, dynamic> map) {
    return TravelPreferences(
      pax: map['pax'] ?? 1,
      hasChildren: map['has_children'] ?? map['hasChildren'] ?? false,
      childrenCount: map['children_count'] ?? map['childrenCount'] ?? 0,
      childrenAgeRange: map['children_age_range'] ?? map['childrenAgeRange'] ?? "",
      hasElderly: map['has_elderly'] ?? map['hasElderly'] ?? false,
      isHalal: map['is_halal'] ?? false,
      tripVibe: List<String>.from(map['trip_vibe'] ?? map['tripVibe'] ?? ["Balanced"]), 
      budget: map['budget'] ?? "Standard",
      accommodation: map['accommodation'] ?? "Hotel",
      currency: map['currency'] ?? "USD",
    );
  }

  // 3. The Prompt String (AI Instruction)
  String toPromptString() {
    String childDetails = hasChildren 
        ? "($childrenCount children, Ages: $childrenAgeRange)" 
        : "No children";

    return """
    - Travelers: $pax pax
    - Children: $childDetails
    - Elderly: ${hasElderly ? "Yes (Minimize walking)" : "No"}
    - Halal Preference: ${isHalal ? "STRICT YES" : "None"}
    - Trip Vibe/Interests: ${tripVibe.join(", ")}
    - Budget Level: $budget
    - Accommodation Preference: $accommodation
    - Currency: $currency
    """;
  }
}