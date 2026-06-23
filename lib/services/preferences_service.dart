import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/travel_preferences.dart';

class PreferencesService {
  static Future<TravelPreferences> fetch() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return TravelPreferences.defaults();

    try {
      final doc = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (doc == null) return TravelPreferences.defaults();
      return TravelPreferences.fromMap(doc);
    } catch (_) {
      // If Firestore blocked/offline/etc, app still works
      return TravelPreferences.defaults();
    }
  }
}
