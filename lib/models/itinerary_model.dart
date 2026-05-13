import 'package:cloud_firestore/cloud_firestore.dart';

class ItineraryModel {
  String? id; // Firestore Document ID
  String userId;
  String tripName;
  String country;
  String duration; 
  String summary;
  String coverImage;
  List<String> tags;
  bool isHalal;
  double rating;
  List<DaySchedule> days;
  DateTime createdAt;
  String status; // 'upcoming' or 'completed'

  ItineraryModel({
    this.id,
    required this.userId,
    required this.tripName,
    required this.country,
    required this.duration,
    required this.summary,
    required this.coverImage,
    required this.tags,
    required this.isHalal,
    this.rating = 0.0,
    required this.days,
    required this.createdAt,
    this.status = 'upcoming',
  });

  // 🏭 FACTORY: Smartly converts JSON/Firestore Map to Object
  factory ItineraryModel.fromMap(Map<String, dynamic> map, String docId) {
    
    // 🛡️ LOGIC: Find the 'days' list wherever the AI hid it
    List<dynamic> rawDays = [];
    if (map['trip_data'] != null && map['trip_data']['days'] != null) {
      // Structure A: { trip_data: { days: [...] } }
      rawDays = map['trip_data']['days'];
    } else if (map['days'] != null) {
      // Structure B: { days: [...] } (Sometimes AI does this)
      rawDays = map['days'];
    }

    // 🛡️ LOGIC: Handle Dates safely (Firestore Timestamp vs String)
    DateTime parsedDate = DateTime.now();
    if (map['created_at'] != null) {
      if (map['created_at'] is Timestamp) {
        parsedDate = (map['created_at'] as Timestamp).toDate();
      } else if (map['created_at'] is String) {
        parsedDate = DateTime.tryParse(map['created_at']) ?? DateTime.now();
      }
    }

    return ItineraryModel(
      id: docId,
      userId: map['user_id'] ?? '',
      tripName: map['trip_name'] ?? 'Unknown Trip',
      country: map['country'] ?? 'Unknown',
      duration: map['duration'] ?? 'Flexible',
      summary: map['full_content'] ?? '',
      coverImage: map['cover_image'] ?? '',
      tags: List<String>.from(map['tags'] ?? []),
      isHalal: map['is_halal'] ?? false,
      rating: (map['rating'] ?? 0).toDouble(), // Force double
      status: map['status'] ?? 'upcoming',
      createdAt: parsedDate,
      days: rawDays.map((d) => DaySchedule.fromMap(d)).toList(),
    );
  }

  // 📤 METHOD: Convert Object back to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'trip_name': tripName,
      'country': country,
      'duration': duration,
      'full_content': summary,
      'cover_image': coverImage,
      'tags': tags,
      'is_halal': isHalal,
      'rating': rating,
      'status': status,
      'created_at': Timestamp.fromDate(createdAt), // Save as Timestamp
      'trip_data': {
        'days': days.map((d) => d.toMap()).toList(),
      },
    };
  }
}

// --- SUB-CLASSES ---

class DaySchedule {
  int day;
  String theme;
  List<Activity> activities;

  DaySchedule({required this.day, required this.theme, required this.activities});

  factory DaySchedule.fromMap(Map<String, dynamic> map) {
    return DaySchedule(
      day: map['day'] ?? 1,
      theme: map['theme'] ?? 'Adventure',
      activities: (map['activities'] as List? ?? [])
          .map((a) => Activity.fromMap(a))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'day': day,
      'theme': theme,
      'activities': activities.map((a) => a.toMap()).toList(),
    };
  }
}

class Activity {
  String time;
  String title;
  String desc;
  bool isDone;

  Activity({
    required this.time,
    required this.title,
    required this.desc,
    this.isDone = false,
  });

  factory Activity.fromMap(Map<String, dynamic> map) {
    return Activity(
      time: map['time'] ?? '',
      title: map['title'] ?? '',
      desc: map['desc'] ?? '',
      isDone: map['isDone'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'time': time,
      'title': title,
      'desc': desc,
      'isDone': isDone,
    };
  }
}