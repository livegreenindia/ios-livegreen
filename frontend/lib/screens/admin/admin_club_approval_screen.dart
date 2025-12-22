import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/club.dart';
import '../../services/club_service.dart';
import '../community/club_details_screen.dart';

class AdminClubApprovalScreen extends StatefulWidget {
  const AdminClubApprovalScreen({super.key});

  @override
  State<AdminClubApprovalScreen> createState() => _AdminClubApprovalScreenState();
}

class _AdminClubApprovalScreenState extends State<AdminClubApprovalScreen>
    with SingleTickerProviderStateMixin {
  final _clubService = ClubService();
  final _auth = FirebaseAuth.instance;
  late TabController _tabController;

  List<Club> _pendingClubs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPendingClubs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPendingClubs() async {
    try {
      setState(() => _isLoading = true);
      final pendingClubs = await _clubService.getPendingClubs();

      // Get rejected clubs separately if needed
      setState(() {
        _pendingClubs = pendingClubs.where((c) => c.isPending).toList();
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

  Future<void> _approveClub(Club club) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Club?'),
        content: Text('Approve "${club.name}" club?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final adminId = _auth.currentUser?.uid ?? 'admin';
      await _clubService.approveClub(club.id, adminId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Club approved!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _loadPendingClubs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving club: $e')),
        );
      }
    }
  }

  Future<void> _rejectClub(Club club) async {
    final TextEditingController reasonController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Club'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Rejecting "${club.name}"'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason',
                hintText: 'Why are you rejecting this club?',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, reasonController.text),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    try {
      await _clubService.rejectClub(club.id, result);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Club rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      _loadPendingClubs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting club: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Club Approvals'),
        elevation: 0,
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: 'Pending (${_pendingClubs.length})'),
              const Tab(text: 'Rejected'),
            ],
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPendingTab(),
                      _buildRejectedTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingTab() {
    if (_pendingClubs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No pending clubs',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'All clubs have been reviewed',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _pendingClubs.length,
      itemBuilder: (context, index) {
        final club = _pendingClubs[index];
        return _buildClubApprovalCard(club);
      },
    );
  }

  Widget _buildRejectedTab() {
    return Center(
      child: Text(
        'Rejected clubs will be shown here',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  Widget _buildClubApprovalCard(Club club) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Club Image
          if (club.imageUrl != null)
            Container(
              height: 150,
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
                // Title and Category
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            club.name,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                const SizedBox(height: 12),

                // Description
                Text(
                  club.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // Creator Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      if (club.creatorImageUrl != null)
                        CircleAvatar(
                          backgroundImage: NetworkImage(club.creatorImageUrl!),
                          radius: 20,
                        )
                      else
                        CircleAvatar(
                          child: Text(club.creatorName[0]),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Created by ${club.creatorName}',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Text(
                              'Location: ${club.location}',
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
                ),
                const SizedBox(height: 16),

                // Tags
                if (club.tags.isNotEmpty) ...[
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: club.tags.map((tag) {
                      return Chip(
                        label: Text(tag),
                        backgroundColor: colorScheme.primary.withOpacity(0.1),
                        labelStyle: TextStyle(
                          color: colorScheme.primary,
                          fontSize: 11,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Contact Info
                if (club.contactEmail != null ||
                    club.phoneNumber != null ||
                    club.website != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (club.contactEmail != null) ...[
                          Row(
                            children: [
                              Icon(Icons.email, size: 16, color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Expanded(child: Text(club.contactEmail!)),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],
                        if (club.phoneNumber != null) ...[
                          Row(
                            children: [
                              Icon(Icons.phone, size: 16, color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Expanded(child: Text(club.phoneNumber!)),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],
                        if (club.website != null) ...[
                          Row(
                            children: [
                              Icon(Icons.language, size: 16, color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Expanded(child: Text(club.website!)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _rejectClub(club),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: colorScheme.error),
                        ),
                        child: Text(
                          'Reject',
                          style: TextStyle(color: colorScheme.error),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _approveClub(club),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: const Text('Approve'),
                      ),
                    ),
                  ],
                ),

                // View Full Details Button
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ClubDetailsScreen(clubId: club.id),
                        ),
                      ).then((_) => _loadPendingClubs());
                    },
                    icon: const Icon(Icons.preview),
                    label: const Text('View Full Details'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
