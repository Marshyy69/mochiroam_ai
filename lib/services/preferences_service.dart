import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/travel_preferences.dart';

class PreferencesService {
  static Future<TravelPreferences> fetch() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return TravelPreferences.defaults();

    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (!doc.exists || doc.data() == null)
        return TravelPreferences.defaults();
      return TravelPreferences.fromMap(doc.data()!);
    } catch (_) {
      // If Firestore blocked/offline/etc, app still works
      return TravelPreferences.defaults();
    }
  }
}
