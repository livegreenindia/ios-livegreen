import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../services/wearable_integration_service.dart';

class IntegrationProgressScreen extends StatefulWidget {
  final String uid;
  const IntegrationProgressScreen({super.key, required this.uid});

  @override
  State<IntegrationProgressScreen> createState() => _IntegrationProgressScreenState();
}

class _IntegrationProgressScreenState extends State<IntegrationProgressScreen> with SingleTickerProviderStateMixin {
  final WearableIntegrationService _service = WearableIntegrationService();
  late AnimationController _animationController;
  
  String _statusMessage = 'Initializing connection...';
  double _progress = 0.0;
  // ignore: unused_field
  int _step = 0;
  // ignore: unused_field
  int _total = 1;
  bool _running = true;
  bool _error = false;
  String? _errorMessage;
  Map<String, dynamic>? _fitbitData;
  // ignore: unused_field
  Map<String, dynamic>? _samsungData;
  
  // Parsed Fitbit data for UI display
  int? _steps;
  double? _distance;
  int? _calories;
  int? _activeMinutes;
  int? _heartRate;
  String? _heartRateZone;
  String? _lastSyncTime;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _service.registerProgressCallback(_onProgress);
    _service.registerDataCallback(_onData);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _service.cancel();
    _animationController.dispose();
    super.dispose();
  }

  String _getUserFriendlyError(String error) {
    final errorLower = error.toLowerCase();
    
    if (errorLower.contains('no client_id') || errorLower.contains('not configured')) {
      return 'Setup needed: Please configure your Fitbit connection in settings.';
    } else if (errorLower.contains('invalid redirect') || errorLower.contains('redirect_uri')) {
      return 'Connection error: Unable to communicate with Fitbit. Please try again.';
    } else if (errorLower.contains('authorization code not returned')) {
      return 'Authorization cancelled: Please approve access to continue syncing.';
    } else if (errorLower.contains('token exchange failed') || errorLower.contains('exchange failed')) {
      return 'Connection failed: Unable to complete authorization. Please try again.';
    } else if (errorLower.contains('network') || errorLower.contains('timeout')) {
      return 'Network error: Please check your internet connection and try again.';
    } else if (errorLower.contains('firestore') || errorLower.contains('permission')) {
      return 'Unable to save data: Please check your account permissions.';
    } else if (errorLower.contains('rate_limited') || errorLower.contains('too many')) {
      return 'Too many requests: Please wait a moment and try again.';
    } else if (errorLower.contains('unauthorized') || errorLower.contains('401')) {
      return 'Session expired: Please sign in again.';
    }
    
    // Generic user-friendly message
    return 'Something went wrong. Please try again or contact support if the problem persists.';
  }

  void _parseFitbitData(Map<String, dynamic> data) {
    try {
      // Parse steps data
      if (data['fitbit_steps_payload'] != null) {
        final stepsPayload = data['fitbit_steps_payload'] as Map<String, dynamic>;
        if (stepsPayload['activities-steps'] != null) {
          final stepsList = stepsPayload['activities-steps'] as List;
          if (stepsList.isNotEmpty) {
            final todaySteps = stepsList.first as Map<String, dynamic>;
            _steps = int.tryParse(todaySteps['value']?.toString() ?? '0');
          }
        }
      }

      // Parse calories
      if (data['fitbit_calories_payload'] != null) {
        final caloriesPayload = data['fitbit_calories_payload'] as Map<String, dynamic>;
        if (caloriesPayload['activities-calories'] != null) {
          final caloriesList = caloriesPayload['activities-calories'] as List;
          if (caloriesList.isNotEmpty) {
            final caloriesData = caloriesList.first as Map<String, dynamic>;
            _calories = int.tryParse(caloriesData['value']?.toString() ?? '0');
          }
        }
      }

      // Parse distance
      if (data['fitbit_distance_payload'] != null) {
        final distancePayload = data['fitbit_distance_payload'] as Map<String, dynamic>;
        if (distancePayload['activities-distance'] != null) {
          final distanceList = distancePayload['activities-distance'] as List;
          if (distanceList.isNotEmpty) {
            final distanceData = distanceList.first as Map<String, dynamic>;
            _distance = double.tryParse(distanceData['value']?.toString() ?? '0');
          }
        }
      }

      // Parse heart rate
      if (data['fitbit_heart_payload'] != null) {
        final heartPayload = data['fitbit_heart_payload'] as Map<String, dynamic>;
        if (heartPayload['activities-heart'] != null) {
          final heartList = heartPayload['activities-heart'] as List;
          if (heartList.isNotEmpty) {
            final heartData = heartList.first as Map<String, dynamic>;
            final value = heartData['value'];
            if (value != null && value is Map) {
              _heartRate = value['restingHeartRate'] as int?;
              // Get heart rate zones
              if (value['heartRateZones'] != null) {
                final zones = value['heartRateZones'] as List;
                int maxMinutes = 0;
                for (final zone in zones) {
                  final minutes = zone['minutes'] as int? ?? 0;
                  if (minutes > maxMinutes) {
                    maxMinutes = minutes;
                    _heartRateZone = zone['name'] as String?;
                  }
                }
              }
            }
          }
        }
      }

      // Parse activity summary
      if (data['fitbit_activity_summary'] != null) {
        final summary = data['fitbit_activity_summary'] as Map<String, dynamic>;
        if (summary['summary'] != null) {
          final summaryData = summary['summary'] as Map<String, dynamic>;
          _activeMinutes = summaryData['veryActiveMinutes'] as int? ?? 0;
          _activeMinutes = (_activeMinutes ?? 0) + (summaryData['fairlyActiveMinutes'] as int? ?? 0);
        }
      }
      
      _lastSyncTime = DateTime.now().toString().substring(0, 19);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error parsing Fitbit data: $e');
    }
  }

  void _onProgress(String message, double percent, int step, int total) {
    if (!mounted) return;
    setState(() {
      _statusMessage = message;
      _progress = percent.clamp(0.0, 1.0);
      _step = step;
      _total = total;
      _running = percent < 1.0;
    });
  }

  Future<void> _start() async {
    if (!mounted) return;
    setState(() {
      _statusMessage = 'Connecting to Fitbit...';
      _progress = 0.05;
      _running = true;
      _error = false;
      _errorMessage = null;
    });

    try {
      await _service.startFullSync(widget.uid);
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Sync completed successfully! ✓';
        _progress = 1.0;
        _running = false;
      });
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Wearables synced successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      // Auto-close after brief delay
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final userFriendlyError = _getUserFriendlyError(e.toString());
      setState(() {
        _error = true;
        _errorMessage = userFriendlyError;
        _running = false;
        _progress = 0.0;
      });
    }
  }

  void _onData(Map<String, dynamic> fitbit, Map<String, dynamic> samsung) {
    if (!mounted) return;
    setState(() {
      if (fitbit.isNotEmpty) {
        _fitbitData = fitbit;
        _parseFitbitData(fitbit);
      }
      if (samsung.isNotEmpty) _samsungData = samsung;
    });
  }

  void _cancel() {
    _service.cancel();
    if (!mounted) return;
    setState(() {
      _running = false;
      _statusMessage = 'Sync cancelled';
    });
  }

  void _retry() {
    if (!mounted) return;
    setState(() {
      _error = false;
      _errorMessage = null;
      _fitbitData = null;
      _samsungData = null;
      _steps = null;
      _distance = null;
      _calories = null;
      _activeMinutes = null;
    });
    _start();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Wearables'),
        elevation: 0,
        actions: [
          if (_running)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _cancel,
              tooltip: 'Cancel sync',
            ),
        ],
      ),
      body: SafeArea(
        child: _error ? _buildErrorView(theme) : _buildSyncView(theme),
      ),
    );
  }

  Widget _buildErrorView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Sync Failed',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'An unexpected error occurred',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncView(ThemeData theme) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status message
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      if (_running)
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(theme.primaryColor),
                          ),
                        )
                      else
                        Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 20,
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Progress indicator
                if (_running) ...[
                  Center(
                    child: SizedBox(
                      width: 160,
                      height: 160,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 160,
                            height: 160,
                            child: CircularProgressIndicator(
                              value: _progress,
                              strokeWidth: 12,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation(theme.primaryColor),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${(_progress * 100).round()}%',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Syncing...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
                
                // Fitbit data display
                if (_fitbitData != null && _steps != null) ...[
                  Text(
                    'Today\'s Activity',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildActivityCard(
                    icon: Icons.directions_walk,
                    label: 'Steps',
                    value: _steps?.toString() ?? '0',
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (_distance != null)
                        Expanded(
                          child: _buildSmallActivityCard(
                            icon: Icons.straighten,
                            label: 'Distance',
                            value: '${_distance!.toStringAsFixed(2)} km',
                            color: Colors.green,
                          ),
                        ),
                      if (_distance != null && _calories != null)
                        const SizedBox(width: 12),
                      if (_calories != null)
                        Expanded(
                          child: _buildSmallActivityCard(
                            icon: Icons.local_fire_department,
                            label: 'Calories',
                            value: _calories.toString(),
                            color: Colors.orange,
                          ),
                        ),
                    ],
                  ),
                  if (_activeMinutes != null) ...[
                    const SizedBox(height: 12),
                    _buildActivityCard(
                      icon: Icons.timer,
                      label: 'Active Minutes',
                      value: _activeMinutes.toString(),
                      color: Colors.purple,
                    ),
                  ],
                  if (_heartRate != null) ...[
                    const SizedBox(height: 12),
                    _buildActivityCard(
                      icon: Icons.favorite,
                      label: 'Resting Heart Rate',
                      value: '$_heartRate bpm${_heartRateZone != null ? " ($_heartRateZone)" : ""}',
                      color: Colors.red,
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
                
                // Success state
                if (!_running && !_error && _fitbitData != null) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green.shade700,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Sync Complete!',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your Fitbit data has been successfully synced.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.green.shade700,
                          ),
                        ),
                        if (_lastSyncTime != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Last synced: $_lastSyncTime',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        
        // Bottom button
        if (!_running && !_error)
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActivityCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallActivityCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
