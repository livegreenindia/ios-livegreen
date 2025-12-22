import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/club.dart';
import '../../services/club_service.dart';
import 'create_event_screen.dart';

class ClubDetailsScreen extends StatefulWidget {
  final String clubId;

  const ClubDetailsScreen({super.key, required this.clubId});

  @override
  State<ClubDetailsScreen> createState() => _ClubDetailsScreenState();
}

class _ClubDetailsScreenState extends State<ClubDetailsScreen> with SingleTickerProviderStateMixin {
    // Share club with deep link
  void _shareClub() {
    if (_club == null) return;
    
    final clubLink = 'https://livegreen.app/clubs/${_club!.id}';
    final shareText = '''
🌱 Join ${_club!.name}!

${_club!.description}

📍 ${_club!.location}
👥 ${_club!.memberCount} members

Join us on LiveGreen:
$clubLink
''';
    
    Share.share(shareText);
  }

  // Helper to add event to Google Calendar
    Future<void> _addEventToGoogleCalendar(ClubActivity event) async {
      final title = Uri.encodeComponent(event.title);
      final details = Uri.encodeComponent(event.content ?? '');
      final location = Uri.encodeComponent(_club?.location ?? '');
      final start = event.eventDate?.toUtc().toIso8601String().replaceAll('-', '').replaceAll(':', '').split('.').first ?? '';
      final end = event.eventDate != null ?
        DateTime.fromMillisecondsSinceEpoch(event.eventDate!.millisecondsSinceEpoch + 3600000).toUtc().toIso8601String().replaceAll('-', '').replaceAll(':', '').split('.').first : '';
      final url = 'https://www.google.com/calendar/render?action=TEMPLATE&text=$title&details=$details&location=$location&dates=$start/$end';
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open Google Calendar')),
          );
        }
      }
    }
  final _clubService = ClubService();
  final _auth = FirebaseAuth.instance;

  late TabController _tabController;
  Club? _club;
  List<ClubActivity> _activities = [];
  bool _isLoading = true;
  bool _isJoinLoading = false;
  bool _isMember = false;
  List<ClubMessage> _messages = [];
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild to show/hide FAB
    });
    _loadClubDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadClubDetails() async {
    try {
      final club = await _clubService.getClubById(widget.clubId);
      final activities = await _clubService.getClubActivities(widget.clubId);
      final messages = await _clubService.getMessages(widget.clubId);
      final currentUserId = _auth.currentUser?.uid;

      setState(() {
        _club = club;
        _activities = activities;
        _messages = messages;
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
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareClub(),
            tooltip: 'Share Club',
          ),
        ],
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
                Tab(text: 'Events'),
                Tab(text: 'Messages'),
                Tab(text: 'Members'),
              ],
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAboutTab(),
                  _buildEventsTab(),
                  _buildMessagesTab(),
                  _buildMembersTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _isMember && _tabController.index == 1
          ? FloatingActionButton.extended(
              onPressed: () async {
                if (_club == null) return;
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateEventScreen(club: _club!),
                  ),
                );
                if (result == true) {
                  _loadClubDetails();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Event'),
            )
          : null,
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

  Widget _buildEventsTab() {
    // Filter only events (type == 'event')
    final events = _activities.where((a) => a.type.toLowerCase() == 'event').toList();
    
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No events yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_isMember)
              ElevatedButton.icon(
                onPressed: () async {
                  if (_club == null) return;
                  // Navigate to create event screen
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateEventScreen(club: _club!),
                    ),
                  );
                  // Refresh events if event was created
                  if (result == true) {
                    _loadClubDetails();
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Create Event'),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return _buildEventCard(event);
      },
    );
  }

  Widget _buildMessagesTab() {
    if (!_isMember) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Join the club to chat',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Messages list
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Text(
                    'No messages yet. Start the conversation!',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  reverse: true,
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[_messages.length - 1 - index];
                    final isCurrentUser = message.userId == _auth.currentUser?.uid;
                    return _buildMessageBubble(message, isCurrentUser);
                  },
                ),
        ),
        // Message input
        Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outline,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  maxLines: null,
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(ClubMessage message, bool isCurrentUser) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isCurrentUser) ...[
            CircleAvatar(
              backgroundImage: message.userImage != null
                  ? NetworkImage(message.userImage!)
                  : null,
              radius: 16,
              child: message.userImage == null
                  ? Text(message.userName[0].toUpperCase())
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? colorScheme.primary
                    : colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: !isCurrentUser
                    ? Border.all(color: colorScheme.outline.withOpacity(0.3))
                    : null,
              ),
              child: Column(
                crossAxisAlignment:
                    isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isCurrentUser)
                    Text(
                      message.userName,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isCurrentUser ? Colors.white : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatMessageTime(message.timestamp),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      color: isCurrentUser ? Colors.white70 : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isCurrentUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundImage: _auth.currentUser?.photoURL != null
                  ? NetworkImage(_auth.currentUser!.photoURL!)
                  : null,
              radius: 16,
              child: _auth.currentUser?.photoURL == null
                  ? Text(_auth.currentUser?.displayName?[0].toUpperCase() ?? 'U')
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _club == null) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      // Create message
      final message = ClubMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        clubId: _club!.id,
        userId: currentUser.uid,
        userName: currentUser.displayName ?? 'Anonymous',
        userImage: currentUser.photoURL,
        content: text,
        timestamp: DateTime.now(),
      );

      // Clear input immediately for better UX
      _messageController.clear();

      // Add to local list
      setState(() {
        _messages.add(message);
      });

      // Save message to Firestore
      await _clubService.addMessage(_club!.id, message);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatMessageTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${time.month}/${time.day}';
    }
  }

  Widget _buildEventCard(ClubActivity event) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateStr = event.eventDate != null ? _formatEventDate(event.eventDate!) : 'TBD';

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event header with date and action buttons
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.calendar_today, color: colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                // Calendar and Share buttons
                IconButton(
                  icon: const Icon(Icons.calendar_today, color: Colors.blueAccent),
                  tooltip: 'Add to Google Calendar',
                  onPressed: () => _addEventToGoogleCalendar(event),
                ),
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.green),
                  tooltip: 'Share Event',
                  onPressed: () {
                    final eventLink = 'https://livegreen.app/clubs/${_club?.id}/events/${event.id}';
                    final shareText = '''
🎉 ${event.title}

📅 $dateStr
📍 ${event.location ?? _club?.location ?? 'Location TBA'}

${event.content ?? ''}

🌱 Join us at ${_club?.name ?? ''}!
$eventLink
''';
                    Share.share(shareText, subject: 'LiveGreen Club Event');
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Event description
            Text(
              event.content ?? 'No description',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (event.location != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: colorScheme.outline),
                  const SizedBox(width: 8),
                  Expanded(child: Text(event.location!)),
                ],
              ),
            ],
          ],
        ),
      ),
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
                // Share and Calendar buttons for events
                if (activity.type.toLowerCase() == 'event') ...[
                  IconButton(
                    icon: const Icon(Icons.calendar_today, color: Colors.blueAccent),
                    tooltip: 'Add to Google Calendar',
                    onPressed: () => _addEventToGoogleCalendar(activity),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.green),
                    tooltip: 'Share Event',
                    onPressed: () {
                      final shareText =
                          '''Join the event "${activity.title}" at ${_club?.name ?? ''}!

${activity.content ?? ''}

${_club?.location ?? ''}''';
                      Share.share(shareText, subject: 'LiveGreen Club Event');
                    },
                  ),
                ],
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
// ...existing code...
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

  String _formatEventDate(DateTime date) {
    // Format event dates to show when they're happening
    final now = DateTime.now();
    if (date.isAfter(now)) {
      final difference = date.difference(now);
      if (difference.inDays > 0) {
        return 'In ${difference.inDays} day${difference.inDays == 1 ? '' : 's'}';
      } else if (difference.inHours > 0) {
        return 'In ${difference.inHours}h';
      } else {
        return 'Today';
      }
    } else {
      // Past event
      final difference = now.difference(date);
      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else {
        return 'just now';
      }
    }
  }
}
