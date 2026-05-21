import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/itinerary_model.dart';

class ItineraryService {

  // 1. Save a new Trip — returns the Supabase ID
  Future<String?> saveTrip(ItineraryModel trip) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    final data = trip.toMap()..['user_id'] = user.id;

    final response = await Supabase.instance.client
        .from('itineraries')
        .insert(data)
        .select('id')
        .single();

    return response['id'] as String?;
  }

  // 2. Fetch all Trips (Stream)
  Stream<List<ItineraryModel>> getTripsStream({bool isCompleted = false}) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const Stream.empty();

    return Supabase.instance.client
        .from('itineraries')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) => data
            .where((doc) => doc['user_id'] == user.id && doc['status'] == (isCompleted ? 'completed' : 'upcoming'))
            .map((doc) => ItineraryModel.fromMap(doc, doc['id'] as String))
            .toList());
  }

  // 3. Update Activity Status (Checkbox)
  Future<void> updateActivityStatus(String tripId, List<DaySchedule> days) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    await Supabase.instance.client
        .from('itineraries')
        .update({
      'trip_data': {
        'days': days.map((d) => d.toMap()).toList(),
      }
    })
        .eq('id', tripId)
        .eq('user_id', user.id);
  }
}