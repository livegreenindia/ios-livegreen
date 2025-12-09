import 'package:flutter/material.dart';
import '../../models/club.dart';
import '../../services/club_service.dart';
import 'create_club_screen.dart';
import 'club_details_screen.dart';

class ClubsListScreen extends StatefulWidget {
  const ClubsListScreen({Key? key}) : super(key: key);

  @override
  State<ClubsListScreen> createState() => _ClubsListScreenState();
}

class _ClubsListScreenState extends State<ClubsListScreen> {
  final _clubService = ClubService();
  late TextEditingController _searchController;

  ClubCategory? _selectedCategory;
  List<Club> _clubs = [];
  List<Club> _filteredClubs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadClubs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClubs() async {
    try {
      setState(() => _isLoading = true);
      final clubs = await _clubService.getApprovedClubs(
        category: _selectedCategory,
      );
      setState(() {
        _clubs = clubs;
        _filteredClubs = clubs;
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

  void _filterClubs(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredClubs = _clubs;
      } else {
        _filteredClubs = _clubs
            .where((club) =>
                club.name.toLowerCase().contains(query.toLowerCase()) ||
                club.description.toLowerCase().contains(query.toLowerCase()) ||
                club.tags.any(
                    (tag) => tag.toLowerCase().contains(query.toLowerCase())))
            .toList();
      }
    });
  }

  void _onCategorySelected(ClubCategory? category) {
    setState(() {
      _selectedCategory = category;
    });
    _loadClubs();
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clubs'),
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
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterClubs,
              decoration: InputDecoration(
                hintText: 'Search clubs...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterClubs('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: colorScheme.surfaceVariant,
              ),
            ),
          ),

          // Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedCategory == null,
                  onSelected: (selected) {
                    _onCategorySelected(selected ? null : _selectedCategory);
                  },
                ),
                const SizedBox(width: 8),
                ...ClubCategory.values.map((category) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(_getCategoryName(category)),
                      selected: _selectedCategory == category,
                      onSelected: (selected) {
                        _onCategorySelected(selected ? category : null);
                      },
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Clubs List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredClubs.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        itemCount: _filteredClubs.length,
                        itemBuilder: (context, index) {
                          final club = _filteredClubs[index];
                          return _buildClubCard(club, colorScheme);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildClubCard(Club club, ColorScheme colorScheme) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClubDetailsScreen(clubId: club.id),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12.0),
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                  const SizedBox(height: 8),

                  // Description
                  Text(
                    club.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // Location
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
                  const SizedBox(height: 12),

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
                          fontWeight: FontWeight.w500,
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
                        '${club.activityCount} activities',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  // Tags
                  if (club.tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 4,
                      children: club.tags.take(3).map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      }).toList(),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.groups_2_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            _selectedCategory == null && _searchController.text.isEmpty
                ? 'No clubs yet'
                : 'No clubs found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to create one!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _openCreateClub,
            icon: const Icon(Icons.add),
            label: const Text('Create Club'),
          ),
        ],
      ),
    );
  }

  String _getCategoryName(ClubCategory category) {
    switch (category) {
      case ClubCategory.environment:
        return 'Environment';
      case ClubCategory.wildlife:
        return 'Wildlife';
      case ClubCategory.conservation:
        return 'Conservation';
      case ClubCategory.sustainability:
        return 'Sustainability';
      case ClubCategory.community:
        return 'Community';
      case ClubCategory.education:
        return 'Education';
      case ClubCategory.health:
        return 'Health';
      case ClubCategory.other:
        return 'Other';
    }
  }
}
