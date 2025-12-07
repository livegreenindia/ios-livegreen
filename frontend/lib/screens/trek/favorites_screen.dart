import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';
import '../../models/trek.dart';
import '../../services/trek_service.dart';
import '../../widgets/trek/trek_components.dart';
import 'trek_details_screen.dart';

/// Screen to display user's favorite treks
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final TrekService _trekService = TrekService();
  List<Trek> _favorites = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _error = 'Please sign in to view favorites';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final favorites = await _trekService.getFavoriteTreks();
      if (mounted) {
        setState(() {
          _favorites = favorites;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _openTrekDetails(Trek trek) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrekDetailsScreen(trek: trek),
      ),
    ).then((_) => _loadFavorites()); // Refresh on return in case favorites changed
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          'My Favorites',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: 5,
        itemBuilder: (context, index) => const TrekCardShimmer(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.favorite_border,
                size: 64,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_error!.contains('sign in'))
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                )
              else
                FilledButton.icon(
                  onPressed: _loadFavorites,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
            ],
          ),
        ),
      );
    }

    if (_favorites.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.favorite_border,
                size: 80,
                color: AppColors.error.withOpacity(0.3),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'No favorites yet',
                style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Start exploring and save your favorite\npaths, places, and fitness centers!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.explore),
                label: const Text('Explore Now'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFavorites,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: _favorites.length,
        itemBuilder: (context, index) {
          final trek = _favorites[index];
          return TrekCard(
            trek: trek,
            onTap: () => _openTrekDetails(trek),
            distance: null,
          );
        },
      ),
    );
  }
}
