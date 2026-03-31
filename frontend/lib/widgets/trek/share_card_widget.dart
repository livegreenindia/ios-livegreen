import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class ShareCardWidget extends StatelessWidget {
  final GlobalKey boundaryKey;
  final String title;
  final String distance;
  final String duration;
  final String speed;
  final String elevation;
  final String date;
  final String? backgroundImagePath;

  const ShareCardWidget({
    super.key,
    required this.boundaryKey,
    required this.title,
    required this.distance,
    required this.duration,
    required this.speed,
    required this.elevation,
    required this.date,
    this.backgroundImagePath,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.5, // 3:2 landscape aspect ratio as requested
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.backgroundDark, // fallback
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Background Image
            if (backgroundImagePath != null && backgroundImagePath!.isNotEmpty)
              Image.file(
                File(backgroundImagePath!),
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              )
            else
              // Default gradient background
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      AppColors.primaryDark,
                      AppColors.backgroundDark,
                    ],
                  ),
                ),
              ),

            // 2. Dark Overlay for readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.4),
                    Colors.black.withOpacity(0.85),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),

            // 3. Content overlay
            Padding(
              padding: const EdgeInsets.all(40.0), // Fixed large padding for high-res layout
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Title and date
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    date,
                    style: GoogleFonts.manrope(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Stats Grid
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatItem('Distance', distance, Icons.straighten),
                      _buildStatItem('Duration', duration, Icons.timer),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatItem('Elevation', elevation, Icons.terrain),
                      _buildStatItem('Pace', speed, Icons.speed),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Logo at the bottom right
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.eco, color: AppColors.primaryLight, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'LiveGreen',
                            style: GoogleFonts.manrope(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
