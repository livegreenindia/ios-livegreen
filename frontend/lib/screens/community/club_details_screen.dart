import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/club.dart';
import '../../services/club_service.dart';

class ClubDetailsScreen extends StatefulWidget {
  final String clubId;

  const ClubDetailsScreen({Key? key, required this.clubId}) : super(key: key);

  @override
  State<ClubDetailsScreen> createState() => _ClubDetailsScreenState();
}

class _ClubDetailsScreenState extends State<ClubDetailsScreen> with SingleTickerProviderStateMixin {
  final _clubService = ClubService();
  final _auth = FirebaseAuth.instance;

  late TabController _tabController;
  Club? _club;
  List<ClubActivity> _activities = [];
  bool _isLoading = true;
  bool _isJoinLoading = false;
  bool _isMember = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadClubDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadClubDetails() async {
    try {
      final club = await _clubService.getClubById(widget.clubId);
      final activities = await _clubService.getClubActivities(widget.clubId);
      final currentUserId = _auth.currentUser?.uid;

      setState(() {
        _club = club;
        _activities = activities;
        _isMember = club?.memberIds.contains(currentUserId) ?? false;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading club: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _joinClub() async {
    if (_club == null) return;

    try {
      setState(() => _isJoinLoading = true);
      final userId = _auth.currentUser?.uid;
      final userName = _auth.currentUser?.displayName ?? 'User';

      if (userId != null) {
        await _clubService.joinClub(_club!.id, userId, userName);
        await _loadClubDetails();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You joined the club!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error joining club: $e')),
        );
      }
    } finally {
      setState(() => _isJoinLoading = false);
    }
  }

  Future<void> _leaveClub() async {
    if (_club == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Club?'),
        content: const Text('Are you sure you want to leave this club?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      setState(() => _isJoinLoading = true);
      final userId = _auth.currentUser?.uid;

      if (userId != null) {
        await _clubService.leaveClub(_club!.id, userId);
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error leaving club: $e')),
        );
      }
    } finally {
      setState(() => _isJoinLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Club Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_club == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Club Details')),
        body: const Center(child: Text('Club not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_club!.name),
        elevation: 0,
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 200,
              floating: false,
              pinned: true,
              backgroundColor: colorScheme.surface,
              flexibleSpace: FlexibleSpaceBar(
                background: _club!.imageUrl != null
                    ? Image.network(
                        _club!.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: colorScheme.surfaceVariant,
                            child: Icon(
                              Icons.image_not_supported,
                              color: colorScheme.outline,
                            ),
                          );
                        },
                      )
                    : Container(
                        color: colorScheme.surfaceVariant,
                        child: Icon(
                          Icons.groups_2_outlined,
                          size: 64,
                          color: colorScheme.outline,
                        ),
                      ),
              ),
            ),
          ];
        },
        body: Column(
          children: [
            // Club Header Info
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Category
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _club!.name,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _club!.categoryName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Description
                  Text(
                    _club!.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),

                  // Stats
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        context,
                        Icons.people,
                        _club!.memberCount.toString(),
                        'Members',
                      ),
                      _buildStatItem(
                        context,
                        Icons.article,
                        _club!.activityCount.toString(),
                        'Activities',
                      ),
                      _buildStatItem(
                        context,
                        Icons.calendar_today,
                        _club!.createdAt.year.toString(),
                        'Founded',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Join/Leave Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isJoinLoading
                          ? null
                          : (_isMember ? _leaveClub : _joinClub),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isJoinLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isMember ? 'Leave Club' : 'Join Club'),
                    ),
                  ),
                ],
              ),
            ),

            // Tabs
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'About'),
                Tab(text: 'Activities'),
                Tab(text: 'Members'),
              ],
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAboutTab(),
                  _buildActivitiesTab(),
                  _buildMembersTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, IconData icon, String value, String label) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Icon(icon, color: colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: colorScheme.outline,
          ),
        ),
      ],
    );
  }

  Widget _buildAboutTab() {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location
          if (_club!.location.isNotEmpty) ...[
            Text(
              'Location',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_club!.location),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Map
            if (_club!.latitude != null && _club!.longitude != null) ...[
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.outline),
                ),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(_club!.latitude!, _club!.longitude!),
                    zoom: 15,
                  ),
                  markers: {
                    Marker(
                      markerId: MarkerId(_club!.id),
                      position: LatLng(_club!.latitude!, _club!.longitude!),
                      infoWindow: InfoWindow(title: _club!.name),
                    ),
                  },
                  zoomControlsEnabled: false,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],

          // Creator Info
          Text(
            'Created By',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (_club!.creatorImageUrl != null)
                CircleAvatar(
                  backgroundImage: NetworkImage(_club!.creatorImageUrl!),
                  radius: 24,
                )
              else
                CircleAvatar(
                  child: Text(_club!.creatorName[0]),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _club!.creatorName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      'Founded ${_club!.createdAt.year}',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Tags
          if (_club!.tags.isNotEmpty) ...[
            Text(
              'Tags',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _club!.tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],

          // Contact Info
          if (_club!.contactEmail != null ||
              _club!.phoneNumber != null ||
              _club!.website != null) ...[
            Text(
              'Contact',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            if (_club!.contactEmail != null) ...[
              Row(
                children: [
                  Icon(Icons.email, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_club!.contactEmail!)),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (_club!.phoneNumber != null) ...[
              Row(
                children: [
                  Icon(Icons.phone, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_club!.phoneNumber!)),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (_club!.website != null) ...[
              Row(
                children: [
                  Icon(Icons.language, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_club!.website!)),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildActivitiesTab() {
    if (_activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No activities yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _activities.length,
      itemBuilder: (context, index) {
        final activity = _activities[index];
        return _buildActivityCard(activity);
      },
    );
  }

  Widget _buildActivityCard(ClubActivity activity) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author info
            Row(
              children: [
                if (activity.authorImageUrl != null)
                  CircleAvatar(
                    backgroundImage: NetworkImage(activity.authorImageUrl!),
                    radius: 20,
                  )
                else
                  CircleAvatar(
                    child: Text(activity.authorName[0]),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.authorName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        _formatDate(activity.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Activity title and content
            Text(
              activity.title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(activity.content),
            const SizedBox(height: 12),

            // Activity type badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                activity.type.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Likes and comments
            Row(
              children: [
                Icon(Icons.thumb_up_outlined, size: 16, color: colorScheme.outline),
                const SizedBox(width: 4),
                Text(
                  activity.likeCount.toString(),
                  style: TextStyle(fontSize: 12, color: colorScheme.outline),
                ),
                const SizedBox(width: 16),
                Icon(Icons.comment_outlined, size: 16, color: colorScheme.outline),
                const SizedBox(width: 4),
                Text(
                  activity.commentCount.toString(),
                  style: TextStyle(fontSize: 12, color: colorScheme.outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersTab() {
    return FutureBuilder<List<ClubMember>>(
      future: _clubService.getClubMembers(_club!.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final members = snapshot.data ?? [];

        if (members.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'No members yet',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            final isLeader = _club!.leaderIds.contains(member.userId);

            return Card(
              margin: const EdgeInsets.only(bottom: 12.0),
              child: ListTile(
                leading: member.imageUrl != null
                    ? CircleAvatar(backgroundImage: NetworkImage(member.imageUrl!))
                    : CircleAvatar(child: Text(member.name[0])),
                title: Text(member.name),
                subtitle: Text(isLeader ? 'Club Leader' : 'Member'),
                trailing: isLeader
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Leader',
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'just now';
    }
  }
}
