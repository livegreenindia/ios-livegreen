import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
// ...existing imports
import 'package:image_picker/image_picker.dart';
// mime not required when using server upload flow
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/api.dart';
import '../../config/api.dart' as cfg;
import '../../theme/app_theme.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  // Theme-aware color getters
  Color get primaryColor => AppColors.primary;
  Color get backgroundLight => AppColors.backgroundLight;
  Color get backgroundDark => AppColors.backgroundDark;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _posts = [];
  final _controller = TextEditingController();
  XFile? _pickedImage;
  bool _isAdmin = false;
  bool _checkingRole = true;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    _loadPosts();
  }

  /// Check if current user is an admin
  Future<void> _checkUserRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isAdmin = false;
          _checkingRole = false;
        });
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (mounted) {
        setState(() {
          _isAdmin = doc.data()?['role'] == 'admin';
          _checkingRole = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking user role: $e');
      if (mounted) {
        setState(() {
          _isAdmin = false;
          _checkingRole = false;
        });
      }
    }
  }

  Future<void> _loadPosts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ApiService(baseUrl: cfg.apiBaseUrl);
      final list = await api.getPosts().timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw TimeoutException('Request timed out'),
      );
      _posts = List<Map<String, dynamic>>.from(list.map((e) => Map<String, dynamic>.from(e as Map)));
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? backgroundDark : backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people, color: primaryColor, size: 24),
            const SizedBox(width: 8),
            Text(
              "Community",
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: primaryColor,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: _loading ? Colors.grey : Colors.black87, size: 22),
            tooltip: 'Refresh Posts',
            onPressed: _loading ? null : _loadPosts,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPosts,
        color: primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Section: Post box - Only for admins
              if (_checkingRole)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? backgroundDark.withAlpha((0.6 * 255).round())
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (_isAdmin)
                _postBox(context)
              else
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.withOpacity(0.08),
                        Colors.blue.withOpacity(0.04),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.info_outline,
                          color: Colors.blue[700],
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Only admins can create posts. Like and comment on discussions!',
                          style: GoogleFonts.manrope(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 18),

              // Section: Trending Posts
              Row(
                children: [
                  Icon(Icons.trending_up, color: primaryColor, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    "Trending Discussions",
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              if (_loading)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: primaryColor),
                        const SizedBox(height: 16),
                        Text(
                          'Loading discussions...',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_error != null)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700], size: 40),
                      const SizedBox(height: 12),
                      Text(
                        'Failed to load posts',
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.red[700],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: Colors.red[600],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _loadPosts,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text(
                          'Retry',
                          style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (_posts.isEmpty)
                Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: isDark ? backgroundDark.withAlpha((0.6 * 255).round()) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.forum_outlined, size: 60, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No posts yet',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Be the first to start a discussion!',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              else
                ..._posts.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _postCardFromMap(context, p),
                )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _postCardFromMap(BuildContext context, Map<String, dynamic> p) {
    final user = p['name'] ?? p['uid'] ?? 'User';
    final content = p['text'] ?? '';
    final likes = (p['likes'] ?? 0).toString();
    final comments = (p['commentsCount'] ?? 0).toString();
    final imageUrl = p['imageUrl'];
    return _postCard(context, user: user, content: content, likes: likes, comments: comments, imageUrl: imageUrl, postId: p['id']);
  }

  // --- Post Box ---
  Widget _postBox(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? backgroundDark.withAlpha((0.6 * 255).round()) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withAlpha((0.1 * 255).round())
              : primaryColor.withOpacity(0.15),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          TextField(
            controller: _controller,
            maxLines: 3,
            style: GoogleFonts.manrope(
              fontSize: 13.5,
              color: isDark ? Colors.white : Colors.black,
              height: 1.4,
            ),
            decoration: InputDecoration(
              hintText: "Share your wellness journey...",
              hintStyle: GoogleFonts.manrope(
                color: isDark ? Colors.white54 : Colors.grey[500],
                fontSize: 13.5,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(0),
            ),
          ),
          if (_pickedImage != null) ...[
            const SizedBox(height: 8),
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(_pickedImage!.path),
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => setState(() => _pickedImage = null),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () async {
                  final picker = ImagePicker();
                  final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
                  if (file == null) return;
                  setState(() {
                    _pickedImage = file;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.image_outlined,
                        color: primaryColor,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Photo',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  String text = _controller.text.trim();
                  if (text.isEmpty && _pickedImage == null) return;
                  try {
                    String? imageUrl;
                    final api = ApiService(baseUrl: cfg.apiBaseUrl);
                    if (_pickedImage != null) {
                      final bytes = await File(_pickedImage!.path).readAsBytes();
                      final base64Data = base64Encode(bytes);
                      final filename = _pickedImage!.name;
                      imageUrl = await api.uploadImage(filename, base64Data);
                    }
                    await api.createPost(text, imageUrl: imageUrl);
                    _controller.clear();
                    setState(() => _pickedImage = null);
                    await _loadPosts();
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.white),
                            const SizedBox(width: 12),
                            Text('Post published successfully!'),
                          ],
                        ),
                        backgroundColor: primaryColor,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Failed to post: $e'),
                        backgroundColor: Colors.red[700],
                      ),
                    );
                  }
                },
                child: Text(
                  "Post",
                  style: GoogleFonts.manrope(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Post Card ---
  Widget _postCard(
    BuildContext context, {
    required String user,
    required String content,
    required String likes,
    required String comments,
    String? imageUrl,
    String? postId,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? backgroundDark.withAlpha((0.6 * 255).round()) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withAlpha((0.05 * 255).round())
              : Colors.grey.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withOpacity(0.15),
                      primaryColor.withOpacity(0.08),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person,
                  color: primaryColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  user,
                  style: GoogleFonts.manrope(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Post Content
          Text(
            content,
            style: GoogleFonts.manrope(
              fontSize: 13.5,
              color: isDark ? Colors.white : Colors.black87,
              height: 1.5,
            ),
          ),

          if (imageUrl != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: (() {
                if (imageUrl.startsWith('data:')) {
                  // data URL (base64)
                  final comma = imageUrl.indexOf(',');
                  final base64Part = imageUrl.substring(comma + 1);
                  final bytes = base64Decode(base64Part);
                  return Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 100,
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.broken_image, size: 40),
                        ),
                      );
                    },
                  );
                } else {
                  return Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 200,
                        color: Colors.grey[200],
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 100,
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.broken_image, size: 40),
                        ),
                      );
                    },
                  );
                }
              })(),
            ),
          ],

          const SizedBox(height: 12),

          // Likes + Comments
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  if (postId == null) return;
                  // optimistic UI: increment likes locally
                  final idx = _posts.indexWhere((p) => p['id'] == postId);
                  int previousLikes = 0;
                  if (idx != -1) {
                    previousLikes = (_posts[idx]['likes'] ?? 0) as int;
                    setState(() => _posts[idx]['likes'] = previousLikes + 1);
                  }
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    final api = ApiService(baseUrl: cfg.apiBaseUrl);
                    await api.likePost(postId);
                  } catch (e) {
                    // rollback
                    if (idx != -1) setState(() => _posts[idx]['likes'] = previousLikes);
                    if (!mounted) return;
                    messenger.showSnackBar(SnackBar(content: Text('Failed to like: $e')));
                    return;
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.favorite,
                        size: 16,
                        color: Colors.red[600],
                      ),
                      const SizedBox(width: 5),
                      Text(
                        likes,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.red[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () async {
                  if (postId == null) return;
                  final messenger = ScaffoldMessenger.of(context);
                  final textController = TextEditingController();
                  final result = await showDialog<String?>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: Text(
                        'Add Comment',
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                      ),
                      content: TextField(
                        controller: textController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Share your thoughts...',
                          hintStyle: GoogleFonts.manrope(fontSize: 13),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Cancel', style: GoogleFonts.manrope()),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, textController.text.trim()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text('Post', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  );
                  if (result == null || result.isEmpty) return;
                  try {
                    final api = ApiService(baseUrl: cfg.apiBaseUrl);
                    await api.postComment(postId, result);
                    await _loadPosts();
                    if (!mounted) return;
                  } catch (e) {
                    if (!mounted) return;
                    messenger.showSnackBar(SnackBar(content: Text('Failed to comment: $e')));
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble,
                        size: 16,
                        color: primaryColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        comments,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
