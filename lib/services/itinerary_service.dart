import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/itinerary_model.dart';

class ItineraryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. Save a new Trip — returns the Firestore document ID
  Future<String?> saveTrip(ItineraryModel trip) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final docRef = await _db
        .collection('users')
        .doc(user.uid)
        .collection('itineraries')
        .add(trip.toMap());

    return docRef.id;
  }

  // 2. Fetch all Trips (Stream)
  Stream<List<ItineraryModel>> getTripsStream({bool isCompleted = false}) {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _db
        .collection('users')
        .doc(user.uid)
        .collection('itineraries')
        .where('status', isEqualTo: isCompleted ? 'completed' : 'upcoming')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ItineraryModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // 3. Update Activity Status (Checkbox)
  Future<void> updateActivityStatus(String tripId, List<DaySchedule> days) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _db
        .collection('users')
        .doc(user.uid)
        .collection('itineraries')
        .doc(tripId)
        .update({
      'trip_data.days': days.map((d) => d.toMap()).toList(),
    });
  }
}