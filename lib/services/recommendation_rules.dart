import '../models/travel_preferences.dart';

class RecommendationRules {
static String build(TravelPreferences prefs) {
  final rules = <String>[];

  if (prefs.hasChildren == true) {
    rules.add("• Kid-friendly attractions & easy walking routes");
  }

  if (prefs.hasElderly == true) {
    rules.add("• Minimal walking, elevators & rest stops");
  }

  if ((prefs.pax) >= 5) {
    rules.add("• Group-friendly transport & restaurants");
  }

  if (rules.isEmpty) {
    rules.add("• Standard balanced travel activities");
  }

  return rules.join("\n");
}
}
