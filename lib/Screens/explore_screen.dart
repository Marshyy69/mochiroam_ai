import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/itinerary_model.dart';
import '../widgets/bottom_nav_bar.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String _searchQuery = '';
  String _sortBy = 'Recent';
  final Set<String> _likedPostIds = {};
  final TextEditingController _searchController = TextEditingController();
  final _sortOptions = ['Recent', 'Highest Rated', 'Most Liked'];
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadLikedPosts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Loads all liked post IDs for the current user in a SINGLE batch query.
  Future<void> _loadLikedPosts() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      // Single collectionGroup query instead of N+1 sequential reads
      final likesSnap = await FirebaseFirestore.instance
          .collectionGroup('likes')
          .where(FieldPath.documentId, isEqualTo: uid)
          .get();
      final Set<String> likedIds = {};
      for (var doc in likesSnap.docs) {
        // Parent path: public_posts/{postId}/likes/{uid}
        likedIds.add(doc.reference.parent.parent!.id);
      }
      if (mounted) setState(() {
        _likedPostIds.addAll(likedIds);
      });
    } catch (_) {
      // Fallback: load likes per post (in case collectionGroup index missing)
      final snap = await FirebaseFirestore.instance.collection('public_posts').get();
      final futures = snap.docs.map((doc) => doc.reference.collection('likes').doc(uid).get());
      final results = await Future.wait(futures);
      final Set<String> likedIds = {};
      for (int i = 0; i < results.length; i++) {
        if (results[i].exists) likedIds.add(snap.docs[i].id);
      }
      if (mounted) setState(() {
        _likedPostIds.addAll(likedIds);
      });
    }
  }

  /// Toggles like state with optimistic UI and proper Firestore persistence.
  Future<void> _toggleLike(String postId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final ref = FirebaseFirestore.instance.collection('public_posts').doc(postId);
    final likeRef = ref.collection('likes').doc(uid);

    if (_likedPostIds.contains(postId)) {
      // Optimistic: toggle icon immediately
      setState(() => _likedPostIds.remove(postId));
      // Persist to Firestore (fire-and-forget)
      likeRef.delete();
      ref.update({'likes_count': FieldValue.increment(-1)});
    } else {
      setState(() => _likedPostIds.add(postId));
      likeRef.set({'liked_at': FieldValue.serverTimestamp()});
      ref.update({'likes_count': FieldValue.increment(1)});
    }
  }

  /// Debounced search — only applies filter 500ms after user stops typing.
  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _searchQuery = value.trim());
    });
  }

  Future<void> _copyTrip(BuildContext ctx, ItineraryModel trip) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final data = trip.toMap();
    final copy = ItineraryModel.fromMap(data, '');
    copy.userId = user.uid;
    copy.createdAt = DateTime.now();
    copy.status = 'upcoming';
    await FirebaseFirestore.instance
        .collection('users').doc(user.uid)
        .collection('itineraries').add(copy.toMap());
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text("✨ '${trip.tripName}' saved to your trips!"),
        backgroundColor: const Color(0xFFF06292),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  bool _matchesSearch(Map<String, dynamic> d) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery.toLowerCase();
    final fields = [
      d['country'] ?? '', d['title'] ?? '', d['description'] ?? '',
      d['author_name'] ?? '',
      ...(List<String>.from(d['itinerary_data']?['tags'] ?? [])),
      ...((d['highlights'] as List? ?? []).map((h) => '${h['header']} ${h['link']}')),
    ];
    return fields.any((f) => f.toString().toLowerCase().contains(q));
  }

  List<QueryDocumentSnapshot> _sortPosts(List<QueryDocumentSnapshot> posts) {
    final sorted = List<QueryDocumentSnapshot>.from(posts);
    switch (_sortBy) {
      case 'Highest Rated':
        sorted.sort((a, b) => ((b.data() as Map)['rating'] ?? 0)
            .compareTo((a.data() as Map)['rating'] ?? 0));
        break;
      case 'Most Liked':
        sorted.sort((a, b) => ((b.data() as Map)['likes_count'] ?? 0)
            .compareTo((a.data() as Map)['likes_count'] ?? 0));
        break;
      default:
        break; // Already sorted by created_at from Firestore
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        title: const Text("Explore 🌍",
            style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
        backgroundColor: Colors.white, elevation: 0, centerTitle: true,
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 1),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('public_posts')
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFF06292)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("🌍", style: TextStyle(fontSize: 48)),
                SizedBox(height: 12),
                Text("No posts yet!", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                SizedBox(height: 6),
                Text("Be the first to publish a trip.",
                    style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E))),
              ],
            ));
          }

          final allPosts = snapshot.data!.docs;
          final filtered = allPosts.where((doc) => _matchesSearch(doc.data() as Map<String, dynamic>)).toList();
          final sorted = _sortPosts(filtered);

          return Column(
            children: [
              // Search + Sort bar
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Column(children: [
                  // Search bar
                  TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    onSubmitted: (v) { _debounceTimer?.cancel(); setState(() => _searchQuery = v.trim()); },
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: "Search countries, tags, hotels, attractions...",
                      hintStyle: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFBDBDBD), size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? GestureDetector(
                              onTap: () { _searchController.clear(); setState(() => _searchQuery = ''); },
                              child: const Icon(Icons.close_rounded, color: Color(0xFFBDBDBD), size: 18))
                          : null,
                      filled: true, fillColor: const Color(0xFFFAFAFA),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFF0F0F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFF0F0F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFF06292), width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Sort chips
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _sortOptions.map((opt) {
                        final sel = _sortBy == opt;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _sortBy = opt),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: sel ? const Color(0xFFF06292) : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: sel ? const Color(0xFFF06292) : const Color(0xFFF5E0E8)),
                              ),
                              child: Text(opt, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                  color: sel ? Colors.white : const Color(0xFF757575))),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 4),
                ]),
              ),

              // Post feed
              Expanded(
                child: sorted.isEmpty
                    ? Center(child: Text("No results for \"$_searchQuery\"",
                        style: const TextStyle(fontSize: 14, color: Color(0xFF9E9E9E))))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                        itemCount: sorted.length,
                        itemBuilder: (context, index) {
                          final doc = sorted[index];
                          final postData = doc.data() as Map<String, dynamic>;
                          final tripData = postData['itinerary_data'] as Map<String, dynamic>;
                          final publicTrip = ItineraryModel.fromMap(tripData, doc.id);
                          final images = List<String>.from(postData['images'] ?? []);
                          final liked = _likedPostIds.contains(doc.id);
                          final likes = (postData['likes_count'] ?? 0) as int;

                          return _BlogCard(
                            postData: postData, publicTrip: publicTrip,
                            images: images, liked: liked, likesCount: likes < 0 ? 0 : likes,
                            onTap: () => _showPostModal(context, doc.id, postData, publicTrip, images),
                            onLike: () => _toggleLike(doc.id),
                          ).animate().fade(duration: 400.ms).slideY(begin: 0.06, delay: (index * 50).ms);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Post Detail Modal ─────────────────────────────────────────
  void _showPostModal(BuildContext context, String docId,
      Map<String, dynamic> postData, ItineraryModel trip, List<String> images) {
    final title = postData['title'] ?? trip.tripName;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          final liked = _likedPostIds.contains(docId);
          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: const BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
            child: Column(children: [
              // Drag handle
              Container(margin: const EdgeInsets.symmetric(vertical: 12), height: 4, width: 36,
                  decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(10))),

              // Image gallery
              _ImageCarousel(
                images: images.isNotEmpty ? images : [trip.coverImage],
                height: 240,
              ),

              Expanded(child: ListView(padding: const EdgeInsets.all(20), children: [
                // Author row
                Row(children: [
                  Container(width: 36, height: 36,
                      decoration: const BoxDecoration(color: Color(0xFFFCE4EC), shape: BoxShape.circle),
                      child: Center(child: Text(postData['author_avatar'] ?? "🍡", style: const TextStyle(fontSize: 18)))),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(postData['author_name'] ?? "Traveler", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    Text("${postData['country'] ?? ''} • ${trip.duration}", style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
                  ])),
                  // Like button
                  GestureDetector(
                    onTap: () { _toggleLike(docId); setModalState(() {}); },
                    child: Row(children: [
                      Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: liked ? const Color(0xFFF06292) : const Color(0xFFBDBDBD), size: 22),
                      const SizedBox(width: 4),
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance.collection('public_posts').doc(docId).snapshots(),
                        builder: (_, snap) {
                          final count = (snap.data?.data() as Map<String, dynamic>?)?['likes_count'] ?? 0;
                          return Text("$count",
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF757575)));
                        },
                      ),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  // Rating
                  Row(children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 16),
                    const SizedBox(width: 3),
                    Text(postData['rating'].toString(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ]),
                ]),
                const SizedBox(height: 14),
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Text(postData['description'] ?? "No review provided.",
                    style: const TextStyle(fontSize: 14, color: Color(0xFF616161), height: 1.55)),
                const SizedBox(height: 20),

                // Highlights
                if (postData['highlights'] != null && (postData['highlights'] as List).isNotEmpty) ...[
                  const Text("Highlights 📌", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  ...List.from(postData['highlights']).map((tag) => Container(
                    margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFFCE4EC), borderRadius: BorderRadius.circular(14)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text("📌", style: TextStyle(fontSize: 14)), const SizedBox(width: 8),
                      Expanded(child: RichText(text: TextSpan(style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 13), children: [
                        TextSpan(text: "${tag['header']}: ", style: const TextStyle(fontWeight: FontWeight.w700)),
                        TextSpan(text: tag['link'], style: const TextStyle(color: Color(0xFF1565C0))),
                      ]))),
                    ]),
                  )),
                  const SizedBox(height: 10),
                ],

                // Itinerary Preview
                if (trip.days.isNotEmpty) ...[
                  const Text("Itinerary Preview 📋", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  _ItineraryPreview(trip: trip),
                  const SizedBox(height: 16),
                ],

                // Save button
                SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF06292),
                      foregroundColor: Colors.white, elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  icon: const Icon(Icons.bookmark_add_outlined, size: 20),
                  label: const Text("Save to My Trips", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  onPressed: () { Navigator.pop(ctx); _copyTrip(context, trip); },
                )),
              ])),
            ]),
          );
        });
      },
    );
  }
}

// ── Image Carousel with Dot Indicator ────────────────────────────────────────
class _ImageCarousel extends StatefulWidget {
  final List<String> images;
  final double height;
  const _ImageCarousel({required this.images, required this.height});
  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  int _current = 0;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Stack(alignment: Alignment.bottomCenter, children: [
        PageView.builder(
          itemCount: widget.images.length,
          onPageChanged: (i) => setState(() => _current = i),
          itemBuilder: (_, i) => Image.network(widget.images[i],
              fit: BoxFit.cover, width: double.infinity, cacheWidth: 800,
              errorBuilder: (_, __, ___) => Container(height: widget.height,
                  color: const Color(0xFFFCE4EC),
                  child: const Center(child: Icon(Icons.broken_image_outlined, size: 40, color: Color(0xFFBDBDBD))))),
        ),
        if (widget.images.length > 1)
          Positioned(bottom: 10, child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(widget.images.length, (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _current == i ? 18 : 6, height: 6,
              decoration: BoxDecoration(
                color: _current == i ? Colors.white : Colors.white54,
                borderRadius: BorderRadius.circular(3)),
            )),
          )),
      ]),
    );
  }
}

// ── Itinerary Preview Widget ─────────────────────────────────────────────────
class _ItineraryPreview extends StatefulWidget {
  final ItineraryModel trip;
  const _ItineraryPreview({required this.trip});
  @override
  State<_ItineraryPreview> createState() => _ItineraryPreviewState();
}

class _ItineraryPreviewState extends State<_ItineraryPreview> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.map_outlined, color: Color(0xFFF06292), size: 18),
          const SizedBox(width: 8),
          Text("${widget.trip.country} • ${widget.trip.duration}",
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
        ]),
        const SizedBox(height: 10),
        ...widget.trip.days.map((day) {
          final acts = _expanded ? day.activities : day.activities.take(2).toList();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFFCE4EC), borderRadius: BorderRadius.circular(8)),
              child: Text("Day ${day.day}: ${day.theme}",
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFC2185B))),
            ),
            ...acts.map((a) => Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 4),
              child: Row(children: [
                Container(width: 4, height: 4, decoration: const BoxDecoration(color: Color(0xFFBDBDBD), shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(child: Text("${a.time} — ${a.title}",
                    style: const TextStyle(fontSize: 11, color: Color(0xFF757575)), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            )),
            if (!_expanded && day.activities.length > 2)
              Padding(padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: Text("+ ${day.activities.length - 2} more...",
                      style: const TextStyle(fontSize: 11, color: Color(0xFFBDBDBD), fontStyle: FontStyle.italic))),
            const SizedBox(height: 6),
          ]);
        }),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Center(child: Text(_expanded ? "Show less ▲" : "Show all activities ▼",
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFF06292)))),
        ),
      ]),
    );
  }
}

// ── Blog Card ────────────────────────────────────────────────────────────────
class _BlogCard extends StatefulWidget {
  final Map<String, dynamic> postData;
  final ItineraryModel publicTrip;
  final List<String> images;
  final bool liked;
  final int likesCount;
  final VoidCallback onTap;
  final VoidCallback onLike;

  const _BlogCard({
    required this.postData, required this.publicTrip, required this.images,
    required this.liked, required this.likesCount,
    required this.onTap, required this.onLike,
  });

  @override
  State<_BlogCard> createState() => _BlogCardState();
}

class _BlogCardState extends State<_BlogCard> {
  int _imgPage = 0;

  @override
  Widget build(BuildContext context) {
    final title = widget.postData['title'] ?? widget.publicTrip.tripName;
    final desc = widget.postData['description'] ?? '';
    final rating = (widget.postData['rating'] ?? 0).toDouble();
    final allImages = widget.images.isNotEmpty ? widget.images : [widget.publicTrip.coverImage];

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF5E0E8)),
          boxShadow: [BoxShadow(color: const Color(0xFFF06292).withValues(alpha: 0.07), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Author header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(children: [
              Container(width: 36, height: 36,
                  decoration: const BoxDecoration(color: Color(0xFFFCE4EC), shape: BoxShape.circle),
                  child: Center(child: Text(widget.postData['author_avatar'] ?? "🍡", style: const TextStyle(fontSize: 18)))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.postData['author_name'] ?? "Traveler",
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Text("${widget.postData['country'] ?? ''} • ${widget.publicTrip.duration}",
                    style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 14),
                  const SizedBox(width: 3),
                  Text(rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF795548))),
                ]),
              ),
            ]),
          ),

          // Image carousel
          ClipRRect(
            child: SizedBox(
              height: 190,
              child: Stack(alignment: Alignment.bottomCenter, children: [
                PageView.builder(
                  itemCount: allImages.length,
                  onPageChanged: (i) => setState(() => _imgPage = i),
                  itemBuilder: (_, i) => Image.network(allImages[i],
                      height: 190, width: double.infinity, fit: BoxFit.cover, cacheWidth: 600,
                      errorBuilder: (_, __, ___) => Container(height: 190, color: const Color(0xFFFCE4EC),
                          child: const Center(child: Icon(Icons.broken_image_outlined, size: 40, color: Color(0xFFBDBDBD))))),
                ),
                if (allImages.length > 1)
                  Positioned(bottom: 8, child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(allImages.length, (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: _imgPage == i ? 14 : 5, height: 5,
                      decoration: BoxDecoration(color: _imgPage == i ? Colors.white : Colors.white54, borderRadius: BorderRadius.circular(3)),
                    )),
                  )),
              ]),
            ),
          ),

          // Title + description + like + read more
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E), height: 1.4),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 10),
              Row(children: [
                // Like button
                GestureDetector(
                  onTap: widget.onLike,
                  child: Row(children: [
                    Icon(widget.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: widget.liked ? const Color(0xFFF06292) : const Color(0xFFBDBDBD), size: 20),
                    const SizedBox(width: 4),
                    Text("${widget.likesCount}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF757575))),
                  ]),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFFCE4EC), borderRadius: BorderRadius.circular(12)),
                  child: const Text("View more", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFC2185B))),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}