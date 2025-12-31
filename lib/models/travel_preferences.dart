class TravelPreferences {
  final int pax;
  final bool hasChildren;
  final bool hasElderly;
  final bool isHalal; // ✅ The new field

  TravelPreferences({
    required this.pax,
    required this.hasChildren,
    required this.hasElderly,
    required this.isHalal,
  });

  // ✅ 1. ADD THIS: Default values (Fallback)
  factory TravelPreferences.defaults() {
    return TravelPreferences(
      pax: 2,
      hasChildren: false,
      hasElderly: false,
      isHalal: false,
    );
  }

  // ✅ 2. ADD THIS: Convert from Firebase Map to Object
  factory TravelPreferences.fromMap(Map<String, dynamic> map) {
    return TravelPreferences(
      pax: map['pax'] ?? 2,
      hasChildren: map['has_children'] ?? false,
      hasElderly: map['has_elderly'] ?? false,
      isHalal: map['is_halal'] ?? false, // Read the new field!
    );
  }

  // ✅ 3. The Prompt String (for AI)
  String toPromptString() {
    return """
    - Travelers: $pax people
    - Traveling with Children: ${hasChildren ? "Yes" : "No"}
    - Traveling with Elderly: ${hasElderly ? "Yes" : "No"}
    - Halal/Muslim-Friendly Preference: ${isHalal ? "STRICT YES" : "None"} 
    """;
  }
}