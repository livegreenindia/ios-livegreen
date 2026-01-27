import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../services/audio_streaming_service.dart';

class MeditationScreen extends StatefulWidget {
  const MeditationScreen({super.key});

  @override
  State<MeditationScreen> createState() => _MeditationScreenState();
}

class _MeditationScreenState extends State<MeditationScreen> {
  // Session settings
  int _selectedDuration = 15; // in minutes
  bool _bellEnabled = true;
  String _selectedMode = 'ambiance'; // 'ambiance' or 'voice'
  String? _selectedAmbiance;
  String? _selectedVoice;
  double _volume = 0.7;

  // Session state
  bool _isSessionActive = false;
  int _remainingSeconds = 900; // 15 minutes in seconds
  Timer? _sessionTimer;

  // Audio players
  final AudioPlayer _ambiancePlayer = AudioPlayer();
  final AudioPlayer _voicePlayer = AudioPlayer();
  final AudioPlayer _bellPlayer = AudioPlayer();
  final AudioStreamingService _audioService = AudioStreamingService();

  // Available ambiance sounds
  final List<Map<String, dynamic>> _ambianceSounds = [
    {'name': 'Breeze', 'icon': '🌬️', 'asset': 'sounds/Breeze.mp3'},
    {'name': 'Forest', 'icon': '🌲', 'asset': 'sounds/Forest_sound.mp3'},
    {'name': 'Rain', 'icon': '💧', 'asset': 'sounds/Rain sound.mp3'},
  ];

  // Available guidance voices
  final List<Map<String, dynamic>> _voices = [
    {'name': 'David', 'type': 'Deep', 'gender': 'male'},
  ];

  @override
  void initState() {
    super.initState();
    _updateRemainingSeconds();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _ambiancePlayer.dispose();
    _voicePlayer.dispose();
    _bellPlayer.dispose();
    super.dispose();
  }

  void _updateRemainingSeconds() {
    setState(() {
      _remainingSeconds = _selectedDuration * 60;
    });
  }

  void _toggleMode(String mode) {
    setState(() {
      _selectedMode = mode;
    });
  }

  void _selectDuration(int minutes) {
    if (!_isSessionActive) {
      setState(() {
        _selectedDuration = minutes;
        _remainingSeconds = minutes * 60;
      });
    }
  }

  void _selectAmbiance(String ambiance) {
    if (_isSessionActive) return;
    setState(() {
      _selectedAmbiance = ambiance;
    });
  }

  void _selectVoice(String voice) {
    if (_isSessionActive) return;
    setState(() {
      _selectedVoice = voice;
    });
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _startSession() async {
    if (_isSessionActive) return;

    if (_selectedMode == 'ambiance' && _selectedAmbiance == null) {
      _showSnackBar('Select an ambiance sound to start the session.');
      return;
    }

    if (_selectedMode == 'voice' && _selectedVoice == null) {
      _showSnackBar('Select a voice to start the session.');
      return;
    }

    // Ensure we don't have overlapping audio from a previous run.
    await _ambiancePlayer.stop();
    await _voicePlayer.stop();

    setState(() {
      _isSessionActive = true;
    });

    // Start ambiance or voice guidance
    if (_selectedMode == 'ambiance') {
      _playAmbiance();
    } else {
      _playVoiceGuidance();
    }

    // Start countdown timer
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _endSession();
      }
    });
  }

  void _playAmbiance() async {
    if (_selectedAmbiance == null) return;

    final sound = _ambianceSounds.firstWhere(
      (s) => s['name'] == _selectedAmbiance,
      orElse: () => _ambianceSounds[0],
    );

    try {
      await _ambiancePlayer.setVolume(_volume);
      await _ambiancePlayer.setReleaseMode(ReleaseMode.loop);
      
      // Get audio file path (download if needed)
      final audioPath = await _audioService.getAudioPath(sound['asset']);
      if (audioPath != null) {
        await _ambiancePlayer.play(DeviceFileSource(audioPath));
      } else {
        debugPrint('Failed to load audio file');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to load audio. Check connection.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error playing ambiance: $e');
    }
  }

  void _playVoiceGuidance() async {
    if (_selectedVoice == null) return;

    try {
      await _voicePlayer.setVolume(_volume);
      await _voicePlayer.setReleaseMode(ReleaseMode.loop);
      
      // Get audio file path (download if needed)
      final audioPath = await _audioService.getAudioPath('sounds/Guided Body Scan Meditation.mp3');
      if (audioPath != null) {
        await _voicePlayer.play(DeviceFileSource(audioPath));
      } else {
        debugPrint('Failed to load voice guidance');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to load guided meditation. Check connection.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error playing voice: $e');
    }
  }

  void _pauseSession() {
    _sessionTimer?.cancel();
    _ambiancePlayer.pause();
    _voicePlayer.pause();
    setState(() {
      _isSessionActive = false;
    });
  }

  void _endSession() async {
    _sessionTimer?.cancel();
    _ambiancePlayer.stop();
    _voicePlayer.stop();

    // Play completion bell
    if (_bellEnabled) {
      try {
        await _bellPlayer.play(AssetSource('sounds/bell_complete.mp3'));
      } catch (e) {
        debugPrint('Error playing bell: $e');
      }
    }

    setState(() {
      _isSessionActive = false;
      _remainingSeconds = _selectedDuration * 60;
    });

    // Show completion dialog
    if (mounted) {
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Session Complete! 🧘‍♀️'),
        content: Text(
          'You completed a $_selectedDuration minute meditation session. Great work!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0D1F17) : const Color(0xFF1B3A30);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Body Scan Meditation',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // Session Duration Display
              Text(
                'SESSION DURATION',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),

              Text(
                _formatTime(_remainingSeconds),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 72,
                  fontWeight: FontWeight.w300,
                  height: 1,
                ),
              ),

              const SizedBox(height: 16),

              // Bell Enabled Toggle
              GestureDetector(
                onTap: () {
                  if (!_isSessionActive) {
                    setState(() {
                      _bellEnabled = !_bellEnabled;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _bellEnabled
                        ? const Color(0xFF2D5A44)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF2D5A44),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.notifications,
                        color: _bellEnabled
                            ? const Color(0xFF4ADE80)
                            : Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Bell Enabled',
                        style: GoogleFonts.poppins(
                          color: _bellEnabled
                              ? const Color(0xFF4ADE80)
                              : Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Duration Buttons
              if (!_isSessionActive)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildDurationButton(15),
                    const SizedBox(width: 16),
                    _buildDurationButton(30),
                  ],
                ),

              const SizedBox(height: 24),

              // Description
              Text(
                'Scan your body for sensations of pain,\ntension, or anything out of the ordinary.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 32),

              // Ambiance / Voice Toggle
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2D5A44).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildModeButton(
                        'Ambiance',
                        'ambiance',
                        Icons.terrain,
                      ),
                    ),
                    Expanded(
                      child: _buildModeButton('Voice', 'voice', Icons.person),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Background Ambiance or Guidance Voice
              if (_selectedMode == 'ambiance')
                _buildAmbianceSection()
              else
                _buildVoiceSection(),

              const SizedBox(height: 40),

              // Start/Pause Button
              _isSessionActive ? _buildPauseButton() : _buildStartButton(),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDurationButton(int minutes) {
    final isSelected = _selectedDuration == minutes;
    return GestureDetector(
      onTap: () => _selectDuration(minutes),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4ADE80) : const Color(0xFF2D5A44),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4ADE80)
                : const Color(0xFF4ADE80).withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Text(
          '$minutes min',
          style: GoogleFonts.poppins(
            color: isSelected ? const Color(0xFF0D1F17) : Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton(String label, String mode, IconData icon) {
    final isSelected = _selectedMode == mode;
    return GestureDetector(
      onTap: () => _toggleMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2D5A44) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF4ADE80) : Colors.white70,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmbianceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Background Ambiance',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                'View All',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF4ADE80),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _ambianceSounds.length,
            itemBuilder: (context, index) {
              final sound = _ambianceSounds[index];
              return _buildAmbianceCard(sound['name'], sound['icon']);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAmbianceCard(String name, String icon) {
    final isSelected = _selectedAmbiance == name;
    return GestureDetector(
      onTap: _isSessionActive ? null : () => _selectAmbiance(name),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF2D5A44),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF4ADE80) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            // Background gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.6),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
            ),

            // Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(icon, style: const TextStyle(fontSize: 40)),
                  const SizedBox(height: 12),
                  Text(
                    name,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Selection indicator
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ADE80),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Color(0xFF0D1F17),
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Guidance Voice',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),

        // Volume Slider
        Row(
          children: [
            const Icon(Icons.volume_down, color: Colors.white70, size: 24),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: const Color(0xFF4ADE80),
                  inactiveTrackColor: const Color(0xFF2D5A44),
                  thumbColor: const Color(0xFF4ADE80),
                  overlayColor: const Color(0xFF4ADE80).withOpacity(0.2),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 12,
                  ),
                ),
                child: Slider(
                  value: _volume,
                  onChanged: (value) {
                    setState(() {
                      _volume = value;
                    });
                    _ambiancePlayer.setVolume(value);
                    _voicePlayer.setVolume(value);
                  },
                ),
              ),
            ),
            const Icon(Icons.volume_up, color: Colors.white70, size: 24),
          ],
        ),

        const SizedBox(height: 24),

        // Voice Selection
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _voices.length,
            itemBuilder: (context, index) {
              final voice = _voices[index];
              return _buildVoiceCard(
                voice['name'],
                voice['type'],
                voice['gender'],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceCard(String name, String type, String gender) {
    final isSelected = _selectedVoice == name;
    final isFemale = gender == 'female';

    return GestureDetector(
      onTap: _isSessionActive ? null : () => _selectVoice(name),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF2D5A44),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF4ADE80) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isFemale ? Icons.female : Icons.male,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    name,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    type,
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Selection indicator
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ADE80),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Color(0xFF0D1F17),
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _startSession,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4ADE80),
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_arrow, color: Color(0xFF0D1F17), size: 24),
            const SizedBox(width: 8),
            Text(
              'Start Session',
              style: GoogleFonts.poppins(
                color: const Color(0xFF0D1F17),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPauseButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _pauseSession,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEF4444),
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pause, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            Text(
              'Pause Session',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
