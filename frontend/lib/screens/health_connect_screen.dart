import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/health_connect_service.dart';
import '../theme/app_theme.dart';

/// Health Connect integration screen
/// Replaces the old Fitbit/Samsung integration screens
class HealthConnectScreen extends StatefulWidget {
  final String uid;
  const HealthConnectScreen({super.key, required this.uid});

  @override
  State<HealthConnectScreen> createState() => _HealthConnectScreenState();
}

class _HealthConnectScreenState extends State<HealthConnectScreen> {
  final HealthConnectService _service = HealthConnectService();
  
  bool _isLoading = false;
  bool _isConnected = false;
  bool _isHealthConnectAvailable = false;
  String _statusMessage = '';
  HealthData? _healthData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkHealthConnectStatus();
  }

  Future<void> _checkHealthConnectStatus() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Checking Health Connect availability...';
    });

    try {
      if (Platform.isAndroid) {
        _isHealthConnectAvailable = await _service.isHealthConnectAvailable();
        
        if (!_isHealthConnectAvailable) {
          _statusMessage = 'Health Connect is not installed on this device';
        } else {
          // Check if we already have permissions
          final hasPermissions = await _service.checkPermissions();
          _isConnected = hasPermissions;
          
          if (_isConnected) {
            _statusMessage = 'Connected to Health Connect';
            await _fetchHealthData();
          } else {
            _statusMessage = 'Tap "Connect" to link Health Connect';
          }
        }
      } else {
        _statusMessage = 'Health Connect is only available on Android';
        _isHealthConnectAvailable = false;
      }
    } catch (e) {
      _error = e.toString();
      _statusMessage = 'Error checking Health Connect status';
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _connectHealthConnect() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Checking permissions...';
      _error = null;
    });

    try {
      // First check if already authorized
      final hasPermissions = await _service.checkPermissions();
      
      if (hasPermissions) {
        // Already have permissions, just fetch data
        _isConnected = true;
        _statusMessage = 'Already connected!';
        await _fetchHealthData();
        return;
      }
      
      // Not authorized, open Health Connect permission screen
      _statusMessage = 'Opening Health Connect permissions...';
      await _service.openHealthConnectPermissions();
      _statusMessage = 'Please grant permissions in Health Connect app, then tap "Connect" again';
    } catch (e) {
      _error = e.toString();
      _statusMessage = 'Failed to open permissions';
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchHealthData() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Fetching health data...';
    });

    try {
      _healthData = await _service.fetchHealthData();
      _statusMessage = 'Data synced successfully!';
      
      // Save to Firestore
      await _service.syncHealthData(widget.uid);
    } catch (e) {
      _error = e.toString();
      _statusMessage = 'Failed to fetch data';
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _installHealthConnect() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Opening Play Store...';
    });

    try {
      await _service.installHealthConnect();
      _statusMessage = 'Please install Health Connect from Play Store';
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Health Connect',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Health Connect Logo/Icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.favorite,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            
            // Title
            Text(
              'Health Connect',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sync your health data from connected apps and devices',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),

            // Status Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isConnected 
                      ? Colors.green.withOpacity(0.3) 
                      : Colors.grey.withOpacity(0.2),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isConnected 
                              ? Colors.green.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isConnected 
                              ? Icons.check_circle 
                              : Icons.link_off,
                          color: _isConnected ? Colors.green : Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isConnected ? 'Connected' : 'Not Connected',
                              style: GoogleFonts.manrope(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _statusMessage,
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isLoading)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: Colors.red[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Health Data Display
            if (_healthData != null && _healthData!.hasData) ...[
              Text(
                'Today\'s Health Data',
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              _buildHealthDataGrid(),
              const SizedBox(height: 24),
            ],

            // Action Buttons
            if (!_isHealthConnectAvailable && Platform.isAndroid)
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _installHealthConnect,
                icon: const Icon(Icons.download),
                label: const Text('Install Health Connect'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )
            else if (!_isConnected)
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _connectHealthConnect,
                icon: const Icon(Icons.link),
                label: const Text('Connect Health Connect'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _fetchHealthData,
                icon: const Icon(Icons.sync),
                label: const Text('Sync Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            
            const SizedBox(height: 32),
            
            // Info Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'About Health Connect',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Health Connect is Google\'s unified health data platform. It securely syncs data from your fitness apps and wearables including:\n\n'
                    '• Google Fit\n'
                    '• Samsung Health\n'
                    '• Fitbit\n'
                    '• And many more...',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: Colors.blue[800],
                      height: 1.5,
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

  Widget _buildHealthDataGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        if (_healthData?.steps != null)
          _buildDataCard(
            icon: Icons.directions_walk,
            label: 'Steps',
            value: '${_healthData!.steps}',
            color: Colors.blue,
          ),
        if (_healthData?.heartRate != null)
          _buildDataCard(
            icon: Icons.favorite,
            label: 'Heart Rate',
            value: '${_healthData!.heartRate} bpm',
            color: Colors.red,
          ),
        if (_healthData?.calories != null)
          _buildDataCard(
            icon: Icons.local_fire_department,
            label: 'Calories',
            value: '${_healthData!.calories} kcal',
            color: Colors.orange,
          ),
        if (_healthData?.distanceKm != null)
          _buildDataCard(
            icon: Icons.straighten,
            label: 'Distance',
            value: '${_healthData!.distanceKm!.toStringAsFixed(2)} km',
            color: Colors.green,
          ),
        if (_healthData?.sleepHours != null)
          _buildDataCard(
            icon: Icons.bedtime,
            label: 'Sleep',
            value: '${_healthData!.sleepHours!.toStringAsFixed(1)} hrs',
            color: Colors.purple,
          ),
      ],
    );
  }

  Widget _buildDataCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
