import 'package:flutter/material.dart';
import '../../models/club.dart';
import '../../services/club_service.dart';
import 'club_details_screen.dart';
import 'create_club_screen.dart';

class MyClubsScreen extends StatefulWidget {
  const MyClubsScreen({Key? key}) : super(key: key);

  @override
  State<MyClubsScreen> createState() => _MyClubsScreenState();
}

class _MyClubsScreenState extends State<MyClubsScreen> with SingleTickerProviderStateMixin {
  final _clubService = ClubService();
  late TabController _tabController;

  List<Club> _userClubs = [];
  List<Club> _createdClubs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadClubs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadClubs() async {
    try {
      setState(() => _isLoading = true);
      final userClubs = await _clubService.getUserClubs();
      final createdClubs = await _clubService.getCreatedClubs();

      setState(() {
        _userClubs = userClubs;
        _createdClubs = createdClubs;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading clubs: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _openCreateClub() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateClubScreen()),
    );

    if (result != null) {
      _loadClubs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Clubs'),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: _openCreateClub,
              icon: const Icon(Icons.add),
              label: const Text('Create'),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Joined'),
              Tab(text: 'Created'),
            ],
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildJoinedTab(),
                      _buildCreatedTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinedTab() {
    if (_userClubs.isEmpty) {
      return _buildEmptyState(
        title: 'No clubs yet',
        message: 'Join clubs to get started',
        icon: Icons.groups_2_outlined,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _userClubs.length,
      itemBuilder: (context, index) {
        final club = _userClubs[index];
        return _buildClubCard(club);
      },
    );
  }

  Widget _buildCreatedTab() {
    if (_createdClubs.isEmpty) {
      return _buildEmptyState(
        title: 'No clubs created',
        message: 'Create your first club',
        icon: Icons.add_circle_outline,
        action: _openCreateClub,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _createdClubs.length,
      itemBuilder: (context, index) {
        final club = _createdClubs[index];
        return _buildClubCard(club, showStatus: true);
      },
    );
  }

  Widget _buildClubCard(Club club, {bool showStatus = false}) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClubDetailsScreen(clubId: club.id),
          ),
        ).then((_) => _loadClubs());
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Club Image
            if (club.imageUrl != null)
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Image.network(
                  club.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Icon(
                        Icons.image_not_supported,
                        color: colorScheme.outline,
                      ),
                    );
                  },
                ),
              ),

            // Club Info
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Status
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              club.name,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            if (showStatus)
                              _buildStatusBadge(club.status, colorScheme)
                            else
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
                                  club.categoryName,
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
                  const SizedBox(height: 8),

                  // Stats Row
                  Row(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${club.memberCount} members',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.article_outlined,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${club.activityCount} posts',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  if (club.location.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            club.location,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.outline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(ClubStatus status, ColorScheme colorScheme) {
    Color backgroundColor;
    Color textColor;
    String label;

    switch (status) {
      case ClubStatus.pending:
        backgroundColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange;
        label = 'Pending Review';
        break;
      case ClubStatus.approved:
        backgroundColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green;
        label = 'Approved';
        break;
      case ClubStatus.rejected:
        backgroundColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red;
        label = 'Rejected';
        break;
      case ClubStatus.archived:
        backgroundColor = Colors.grey.withOpacity(0.1);
        textColor = Colors.grey;
        label = 'Archived';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required String title,
    required String message,
    required IconData icon,
    VoidCallback? action,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          if (action != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: action,
              icon: const Icon(Icons.add),
              label: const Text('Create Club'),
            ),
          ],
        ],
      ),
    );
  }
}
