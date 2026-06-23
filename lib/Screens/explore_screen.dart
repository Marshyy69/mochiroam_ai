import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  static String? _lastUid;
  static final Set<String> _likedPostIds = {};
  /// Local optimistic overrides for like counts, keyed by post ID.
  /// This ensures the count updates instantly in the UI before Firestore
  /// streams catch up.
  static final Map<String, int> _likesCountOverrides = {};
  final TextEditingController _searchController = TextEditingController();
  final _sortOptions = ['Recent', 'Highest Rated', 'Most Liked'];
  Timer? _debounceTimer;
  bool _hasReceivedData = false; // Track if we've ever received data from the stream

  Stream<List<Map<String, dynamic>>>? _postsStream;

  @override
  void initState() {
    super.initState();
    _refreshPosts();
    _loadLikedPosts();
  }

  void _refreshPosts() {
    setState(() {
      _postsStream = Supabase.instance.client
          .from('public_posts')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Returns the effective like count for a post, using the local optimistic
  /// override if available, otherwise falling back to the Firestore value.
  int _effectiveLikes(String postId, int firestoreCount) {
    return _likesCountOverrides[postId] ?? firestoreCount;
  }

  Future<void> _loadLikedPosts() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    
    if (_lastUid != uid) {
      _likedPostIds.clear();
      _likesCountOverrides.clear();
      _lastUid = uid;
    }

    try {
      final res = await Supabase.instance.client
          .from('likes')
          .select('post_id')
          .eq('user_id', uid)
          .timeout(const Duration(seconds: 5));
      
      final ids = (res as List).map((row) => row['post_id'] as String).toSet();
      if (mounted) {
        setState(() {
          _likedPostIds.addAll(ids);
        });
      }
    } catch (_) {
      // Quietly ignore timeout or connection errors
    }
  }

  Future<void> _toggleLike(String postId, int currentDisplayedCount) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    if (_likedPostIds.contains(postId)) {
      final newCount = (currentDisplayedCount - 1).clamp(0, 999999);
      setState(() {
        _likedPostIds.remove(postId);
        _likesCountOverrides[postId] = newCount;
      });
      try {
        await Supabase.instance.client.from('likes').delete().match({'post_id': postId, 'user_id': uid});
        await Supabase.instance.client.rpc('decrement_likes', params: {'post_id': postId});
      } catch (_) {
        // Revert on error
        if (mounted) {
          setState(() {
            _likedPostIds.add(postId);
            _likesCountOverrides[postId] = currentDisplayedCount;
          });
        }
      }
    } else {
      final newCount = currentDisplayedCount + 1;
      setState(() {
        _likedPostIds.add(postId);
        _likesCountOverrides[postId] = newCount;
      });
      try {
        await Supabase.instance.client.from('likes').insert({'post_id': postId, 'user_id': uid});
        await Supabase.instance.client.rpc('increment_likes', params: {'post_id': postId});
      } catch (_) {
        // Revert on error
        if (mounted) {
          setState(() {
            _likedPostIds.remove(postId);
            _likesCountOverrides[postId] = currentDisplayedCount;
          });
        }
      }
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
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final data = trip.toMap();
    final copy = ItineraryModel.fromMap(data, '');
    copy.userId = user.id;
    copy.createdAt = DateTime.now();
    copy.status = 'upcoming';
    // Fire-and-forget — don't block the UI
    Supabase.instance.client
        .from('itineraries').insert(copy.toMap())
        .then((_) {}).catchError((_) => null);
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

  List<Map<String, dynamic>> _sortPosts(List<Map<String, dynamic>> posts) {
    final sorted = List<Map<String, dynamic>>.from(posts);
    switch (_sortBy) {
      case 'Highest Rated':
        sorted.sort((a, b) => ((b['rating'] ?? 0) as num)
            .compareTo((a['rating'] ?? 0) as num));
        break;
      case 'Most Liked':
        sorted.sort((a, b) => ((b['likes_count'] ?? 0) as num)
            .compareTo((a['likes_count'] ?? 0) as num));
        break;
      default:
        break; // Already sorted by created_at from Supabase
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
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
        backgroundColor: Colors.white, elevation: 0, centerTitle: true,
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 2),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _postsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFF06292)));
          }
          
          final docs = snapshot.data!;
          if (docs.isEmpty) {
            // If we previously had data but now don't (unlikely), still show empty state
            if (!_hasReceivedData) {
              return const Center(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("🌍", style: TextStyle(fontSize: 48)),
                  SizedBox(height: 12),
                  Text("No posts yet!", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  SizedBox(height: 6),
                  Text("Be the first to publish a trip.",
                      style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E))),
                ],
              ));
            }
            // We had data before, just return an empty container while stream catches up
            return const SizedBox.shrink();
          }

          final allPosts = snapshot.data!;
          final filtered = allPosts.where((doc) => _matchesSearch(doc)).toList();
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
                              child: Text(opt, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
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
                child: RefreshIndicator(
                  color: const Color(0xFFF06292),
                  onRefresh: () async {
                    _refreshPosts();
                    _loadLikedPosts();
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: sorted.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.4,
                              child: Center(
                                child: Text("No results for \"$_searchQuery\"",
                                    style: const TextStyle(fontSize: 14, color: Color(0xFF9E9E9E))),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                          itemCount: sorted.length,
                          itemBuilder: (context, index) {
                            final doc = sorted[index];
                            final postData = doc;
                            final tripData = postData['itinerary_data'] as Map<String, dynamic>? ?? {};
                            final docId = doc['id'] as String;
                            final publicTrip = ItineraryModel.fromMap(tripData, docId);
                            final images = List<String>.from(postData['images'] ?? []);
                            final liked = _likedPostIds.contains(docId);
                            final firestoreLikes = (postData['likes_count'] ?? 0) as int;
                            final effectiveLikes = _effectiveLikes(docId, firestoreLikes);
                            final displayLikes = effectiveLikes < 0 ? 0 : effectiveLikes;

                            return _BlogCard(
                              key: ValueKey(docId),
                              postData: postData, publicTrip: publicTrip,
                              images: images, liked: liked, likesCount: displayLikes,
                              onTap: () => _showPostModal(context, docId, postData, publicTrip, images),
                              onLike: () => _toggleLike(docId, displayLikes),
                            ).animate(key: ValueKey('anim_$docId')).fade(duration: 400.ms).slideY(begin: 0.06, delay: (index * 50).ms);
                          },
                        ),
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

              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _ImageCarousel(
                      images: images.isNotEmpty ? images : [trip.coverImage],
                      height: 240,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                            Builder(builder: (_) {
                              final modalLikes = _effectiveLikes(docId, (postData['likes_count'] ?? 0) as int);
                              final displayCount = modalLikes < 0 ? 0 : modalLikes;
                              return GestureDetector(
                                onTap: () { _toggleLike(docId, displayCount); setModalState(() {}); },
                                child: Row(children: [
                                  Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                      color: liked ? const Color(0xFFF06292) : const Color(0xFFBDBDBD), size: 22),
                                  const SizedBox(width: 4),
                                  Text("$displayCount",
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF757575))),
                                ]),
                              );
                            }),
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
                            const Text("Highlights 📌", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
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
                            const Text("Itinerary Preview 📋", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
    super.key,
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
                Text(desc, style: const TextStyle(fontSize: 13, color: Color(0xFF757575), height: 1.4),
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