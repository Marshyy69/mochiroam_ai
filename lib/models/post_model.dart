import 'package:cloud_firestore/cloud_firestore.dart';
import 'itinerary_model.dart';

class PostModel {
  String? id;
  String authorUid;
  String authorName;
  String authorAvatar;
  String country;
  String title;
  String description;
  List<Map<String, dynamic>> highlights;
  double rating; // ⭐️ Carrying over your existing rating feature!
  int likesCount;
  DateTime createdAt;
  ItineraryModel itinerary; // The actual trip data to copy
  bool isPublic; 
  List<String> images;

  PostModel({
    this.id,
    required this.authorUid,
    required this.authorName,
    required this.authorAvatar,
    required this.country,
    required this.title,
    required this.description,
    this.highlights = const [],
    required this.rating,
    this.likesCount = 0,
    required this.createdAt,
    required this.itinerary,
    this.isPublic = true, // 🆕 Default to public
    this.images = const []
  });

  Map<String, dynamic> toMap() {
    return {
      'author_uid': authorUid,
      'author_name': authorName,
      'author_avatar': authorAvatar,
      'country': country,
      'title': title,
      'description': description,
      'highlights': highlights,
      'rating': rating,
      'likes_count': likesCount,
      'created_at': Timestamp.fromDate(createdAt),
      'itinerary_data': itinerary.toMap(), // 📦 Packs the whole trip into the post!
      'is_public': isPublic, // 🆕 Add to map
      'images': images
    };
  }
}