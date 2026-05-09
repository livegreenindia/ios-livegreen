import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/api.dart';
import '../../config/api.dart' as cfg;
import '../../theme/app_theme.dart';
import 'profile.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  Color get primaryColor => AppColors.primary;
  Color get backgroundLight => AppColors.backgroundLight;
  Color get backgroundDark => AppColors.backgroundDark;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _posts = [];
  bool _isAdmin = false;
  bool _hasFeedAccess = false;
  bool _checkingRole = true;

  // Create post state
  final _captionController = TextEditingController();
  XFile? _pickedImage;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    _loadPosts();
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _checkUserRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() { _isAdmin = false; _hasFeedAccess = false; _checkingRole = false; });
        return;
      }
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted) {
        final data = doc.data();
        final isAdmin = data?['role'] == 'admin';
        setState(() {
          _isAdmin = isAdmin;
          _hasFeedAccess = isAdmin || data?['feedAccess'] == true;
          _checkingRole = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking role: $e');
      if (mounted) setState(() { _isAdmin = false; _hasFeedAccess = false; _checkingRole = false; });
    }
  }

  Future<void> _loadPosts() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = ApiService(baseUrl: cfg.apiBaseUrl);
      final list = await api.getFeedPosts().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Request timed out'),
      );
      if (mounted) {
        setState(() {
          _posts = List<Map<String, dynamic>>.from(
            list.map((e) => Map<String, dynamic>.from(e as Map)),
          );
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitPost() async {
    final text = _captionController.text.trim();
    if (text.isEmpty && _pickedImage == null) return;
    setState(() => _posting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final api = ApiService(baseUrl: cfg.apiBaseUrl);
      String? imageUrl;
      if (_pickedImage != null) {
        final bytes = await File(_pickedImage!.path).readAsBytes();
        final base64Data = base64Encode(bytes);
        imageUrl = await api.uploadFeedImage(_pickedImage!.name, base64Data);
      }
      await api.createFeedPost(text, imageUrl: imageUrl);
      _captionController.clear();
      setState(() { _pickedImage = null; _posting = false; });
      await _loadPosts();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 10),
          Text('Inspiration post published!', style: GoogleFonts.manrope()),
        ]),
        backgroundColor: primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } catch (e) {
      if (mounted) {
        setState(() => _posting = false);
        messenger.showSnackBar(SnackBar(
          content: Text('Failed to post: $e'),
          backgroundColor: Colors.red[700],
        ));
      }
    }
  }

  Future<void> _deletePost(String postId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Post', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to delete this post?', style: GoogleFonts.manrope()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.manrope())),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
            child: Text('Delete', style: GoogleFonts.manrope(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final api = ApiService(baseUrl: cfg.apiBaseUrl);
      await api.deleteFeedPost(postId);
      await _loadPosts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red[700]),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? backgroundDark : backgroundLight,
      appBar: AppBar(
        backgroundColor: isDark ? backgroundDark : Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.spa_rounded, color: primaryColor, size: 22),
            const SizedBox(width: 8),
            Text(
              'Inspiration Feed',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: isDark ? Colors.white : primaryColor,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: _loading ? Colors.grey : (isDark ? Colors.white70 : Colors.black87), size: 22),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadPosts,
          ),
          IconButton(
            icon: Icon(Icons.account_circle_outlined, color: isDark ? Colors.white70 : primaryColor, size: 26),
            tooltip: 'Profile',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _checkingRole
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : !_hasFeedAccess
              ? _buildNoAccessView(isDark)
              : RefreshIndicator(
        onRefresh: _loadPosts,
        color: primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Admin create post card
              if (!_checkingRole && _isAdmin) ...[
                _buildCreatePostCard(context, isDark),
                const SizedBox(height: 18),
              ],

              // Posts header
              Row(children: [
                Icon(Icons.auto_awesome, color: primaryColor, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Latest Posts',
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                    letterSpacing: -0.3,
                  ),
                ),
              ]),
              const SizedBox(height: 12),

              // Posts list
              if (_loading)
                Center(child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(children: [
                    CircularProgressIndicator(color: primaryColor),
                    const SizedBox(height: 14),
                    Text('Loading feed...', style: GoogleFonts.manrope(fontSize: 13, color: Colors.grey[600])),
                  ]),
                ))
              else if (_error != null)
                _buildErrorCard(context, isDark)
              else if (_posts.isEmpty)
                _buildEmptyCard(context, isDark)
              else
                ..._posts.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildPostCard(context, isDark, p),
                )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoAccessView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded, size: 64, color: AppColors.primary.withOpacity(0.4)),
            const SizedBox(height: 20),
            Text(
              'Feed Not Available',
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'The Inspiration Feed is not yet enabled for your account.\nContact an admin to get access.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: Colors.grey[500],
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatePostCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? backgroundDark.withAlpha((0.6 * 255).round()) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(color: primaryColor.withOpacity(0.07), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.spa_rounded, color: primaryColor, size: 16),
            ),
            const SizedBox(width: 10),
            Text(
              'Share Inspiration',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text('Admin', style: GoogleFonts.manrope(fontSize: 11, color: Colors.green[700], fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _captionController,
            maxLines: 3,
            style: GoogleFonts.manrope(fontSize: 13.5, color: isDark ? Colors.white : Colors.black, height: 1.4),
            decoration: InputDecoration(
              hintText: 'Write an inspiring message for your community...',
              hintStyle: GoogleFonts.manrope(color: isDark ? Colors.white54 : Colors.grey[500], fontSize: 13.5),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          if (_pickedImage != null) ...[
            const SizedBox(height: 10),
            Stack(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(File(_pickedImage!.path), height: 160, width: double.infinity, fit: BoxFit.cover),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () => setState(() => _pickedImage = null),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ]),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Image picker
              GestureDetector(
                onTap: () async {
                  final picker = ImagePicker();
                  final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
                  if (file != null) setState(() => _pickedImage = file);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.09),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_photo_alternate_outlined, color: primaryColor, size: 18),
                    const SizedBox(width: 6),
                    Text('Add Photo', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: primaryColor)),
                  ]),
                ),
              ),
              // Post button
              ElevatedButton(
                onPressed: _posting ? null : _submitPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _posting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Post', style: GoogleFonts.manrope(fontSize: 13.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(BuildContext context, bool isDark, Map<String, dynamic> post) {
    final postId = post['id'] as String?;
    final authorName = post['name'] ?? 'Admin';
    final authorPhoto = post['photoURL'] as String?;
    final text = post['text'] as String? ?? '';
    final imageUrl = post['imageUrl'] as String?;
    final likes = post['likes'] ?? 0;
    final commentsCount = post['commentsCount'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? backgroundDark.withAlpha((0.6 * 255).round()) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: primaryColor.withOpacity(0.15),
                backgroundImage: (authorPhoto != null && authorPhoto.isNotEmpty)
                    ? NetworkImage(authorPhoto)
                    : null,
                child: (authorPhoto == null || authorPhoto.isEmpty)
                    ? Icon(Icons.eco, color: primaryColor, size: 20)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    authorName,
                    style: GoogleFonts.manrope(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    'Admin · Inspiration Post',
                    style: GoogleFonts.manrope(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500),
                  ),
                ]),
              ),
              if (_isAdmin && postId != null)
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red[400], size: 20),
                  onPressed: () => _deletePost(postId),
                  tooltip: 'Delete post',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ]),
          ),

          // Image
          if (imageUrl != null && imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.only(topLeft: Radius.zero, topRight: Radius.zero),
              child: _buildPostImage(imageUrl),
            ),

          // Text
          if (text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Text(
                text,
                style: GoogleFonts.manrope(fontSize: 14, color: isDark ? Colors.white : Colors.black87, height: 1.5),
              ),
            ),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Row(children: [
              // Like button
              GestureDetector(
                onTap: () async {
                  if (postId == null) return;
                  final idx = _posts.indexWhere((p) => p['id'] == postId);
                  final prevLikes = idx != -1 ? (_posts[idx]['likes'] ?? 0) as int : 0;
                  if (idx != -1) setState(() => _posts[idx]['likes'] = prevLikes + 1);
                  try {
                    final api = ApiService(baseUrl: cfg.apiBaseUrl);
                    final liked = await api.likeFeedPost(postId);
                    if (idx != -1 && !liked) {
                      setState(() => _posts[idx]['likes'] = (prevLikes - 1).clamp(0, 9999));
                    }
                  } catch (e) {
                    if (idx != -1) setState(() => _posts[idx]['likes'] = prevLikes);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to like: $e')),
                      );
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.favorite_rounded, size: 16, color: Colors.red[600]),
                    const SizedBox(width: 5),
                    Text(
                      likes.toString(),
                      style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red[700]),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 10),
              // Comment button
              GestureDetector(
                onTap: () => _showCommentsSheet(context, isDark, post),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.chat_bubble_rounded, size: 16, color: primaryColor),
                    const SizedBox(width: 5),
                    Text(
                      commentsCount.toString(),
                      style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: primaryColor),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  void _showCommentsSheet(BuildContext context, bool isDark, Map<String, dynamic> post) {
    final postId = post['id'] as String?;
    if (postId == null) return;
    final commentController = TextEditingController();
    bool posting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.92,
            minChildSize: 0.3,
            builder: (ctx, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: isDark ? backgroundDark : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Text('Comments', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black)),
                  ),
                  const Divider(height: 1),
                  // Comments list
                  Expanded(
                    child: FutureBuilder<List<dynamic>>(
                      future: ApiService(baseUrl: cfg.apiBaseUrl).getFeedPosts().then((_) async {
                        // Fetch comments from stream
                        final snap = await FirebaseFirestore.instance
                            .collection('feedPosts')
                            .doc(postId)
                            .collection('comments')
                            .orderBy('ts')
                            .limit(100)
                            .get();
                        return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
                      }),
                      builder: (ctx, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator(color: primaryColor));
                        }
                        final comments = snapshot.data ?? [];
                        if (comments.isEmpty) {
                          return Center(
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.chat_bubble_outline, size: 40, color: Colors.grey[400]),
                              const SizedBox(height: 10),
                              Text('No comments yet. Be the first!', style: GoogleFonts.manrope(color: Colors.grey[500], fontSize: 13)),
                            ]),
                          );
                        }
                        return ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          itemCount: comments.length,
                          itemBuilder: (ctx, i) {
                            final c = comments[i] as Map;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                CircleAvatar(
                                  radius: 15,
                                  backgroundColor: primaryColor.withOpacity(0.15),
                                  child: Icon(Icons.person, size: 16, color: primaryColor),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white.withOpacity(0.07) : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      c['text'] ?? '',
                                      style: GoogleFonts.manrope(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                                    ),
                                  ),
                                ),
                              ]),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  // Comment input
                  Padding(
                    padding: EdgeInsets.only(left: 14, right: 14, bottom: MediaQuery.of(ctx).viewInsets.bottom + 14, top: 10),
                    child: Row(children: [
                      Expanded(
                        child: TextField(
                          controller: commentController,
                          style: GoogleFonts.manrope(fontSize: 13.5, color: isDark ? Colors.white : Colors.black),
                          decoration: InputDecoration(
                            hintText: 'Add a comment...',
                            hintStyle: GoogleFonts.manrope(color: Colors.grey[500], fontSize: 13),
                            filled: true,
                            fillColor: isDark ? Colors.white.withOpacity(0.07) : Colors.grey[100],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: posting ? null : () async {
                          final text = commentController.text.trim();
                          if (text.isEmpty) return;
                          setSheetState(() => posting = true);
                          try {
                            final api = ApiService(baseUrl: cfg.apiBaseUrl);
                            await api.postFeedComment(postId, text);
                            commentController.clear();
                            // Update comment count in parent
                            final idx = _posts.indexWhere((p) => p['id'] == postId);
                            if (idx != -1) {
                              setState(() {
                                _posts[idx]['commentsCount'] = (_posts[idx]['commentsCount'] ?? 0) + 1;
                              });
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to comment: $e'), backgroundColor: Colors.red[700]),
                              );
                            }
                          } finally {
                            setSheetState(() => posting = false);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                          child: posting
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                    ]),
                  ),
                ]),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPostImage(String imageUrl) {
    if (imageUrl.startsWith('data:')) {
      final comma = imageUrl.indexOf(',');
      final base64Part = imageUrl.substring(comma + 1);
      try {
        final bytes = base64Decode(base64Part);
        return Image.memory(bytes, fit: BoxFit.cover, width: double.infinity,
          errorBuilder: (_, __, ___) => _imagePlaceholder());
      } catch (_) {
        return _imagePlaceholder();
      }
    }
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      loadingBuilder: (ctx, child, prog) {
        if (prog == null) return child;
        return Container(
          height: 220,
          color: Colors.grey[200],
          child: Center(child: CircularProgressIndicator(
            value: prog.expectedTotalBytes != null ? prog.cumulativeBytesLoaded / prog.expectedTotalBytes! : null,
          )),
        );
      },
      errorBuilder: (_, __, ___) => _imagePlaceholder(),
    );
  }

  Widget _imagePlaceholder() => Container(
    height: 180,
    color: Colors.grey[200],
    child: const Center(child: Icon(Icons.broken_image_outlined, size: 40, color: Colors.grey)),
  );

  Widget _buildErrorCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(children: [
        Icon(Icons.error_outline, color: Colors.red[700], size: 40),
        const SizedBox(height: 12),
        Text('Failed to load feed', style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.red[700])),
        const SizedBox(height: 6),
        Text(_error!, textAlign: TextAlign.center, style: GoogleFonts.manrope(fontSize: 12, color: Colors.red[600])),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _loadPosts,
          icon: const Icon(Icons.refresh, size: 18),
          label: Text('Retry', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white),
        ),
      ]),
    );
  }

  Widget _buildEmptyCard(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? backgroundDark.withAlpha((0.6 * 255).round()) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1)),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.spa_outlined, size: 60, color: Colors.grey[400]),
        const SizedBox(height: 16),
        Text('No posts yet', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[600])),
        const SizedBox(height: 6),
        Text(
          _isAdmin
              ? 'Share your first inspiration with the community!'
              : 'Check back soon for inspiration posts from the admin.',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(fontSize: 13, color: Colors.grey[500]),
        ),
      ]),
    );
  }
}
