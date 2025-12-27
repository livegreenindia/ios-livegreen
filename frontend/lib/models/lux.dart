import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ambient_light/ambient_light.dart';

class LightMeterApp extends StatefulWidget {
  const LightMeterApp({super.key, this.onStop});

  final VoidCallback? onStop;

  @override
  State<LightMeterApp> createState() => _LightMeterAppState();
}

class _LightMeterAppState extends State<LightMeterApp> {
  double luxValue = 0;
  bool isActive = true;
  bool sensorAvailable = true;

  AmbientLight? _ambientLight;
  StreamSubscription<double>? _lightSubscription;

  @override
  void initState() {
    super.initState();
    startSensor();
  }

  void startSensor() {
    stopSensor();

    try {
      _ambientLight = AmbientLight(frontCamera: true);

      _lightSubscription = _ambientLight!.ambientLightStream.listen(
        (double value) {
          if (!isActive) return;

          setState(() {
            luxValue = value;
          });
        },
        onError: (_) {
          setState(() => sensorAvailable = false);
        },
      );
    } catch (_) {
      setState(() => sensorAvailable = false);
    }
  }

  void stopSensor() {
    _lightSubscription?.cancel();
    _lightSubscription = null;
  }

  @override
  void dispose() {
    stopSensor();
    super.dispose();
  }

  String getRecommendation(double lux) {
    if (lux >= 300 && lux <= 500) return 'Ideal for Reading';
    if (lux >= 500 && lux <= 750) return 'Ideal for General Work';
    if (lux >= 750 && lux <= 1500) return 'Ideal for Detailed Work';
    if (lux >= 100 && lux <= 300) return 'Ideal for Relaxation';
    if (lux >= 50 && lux <= 100) return 'Ambient Lighting';
    if (lux < 50) return 'Too Dark';
    return 'Very Bright';
  }

  bool isInRange(double lux, String activity) {
    switch (activity) {
      case 'Reading':
        return lux >= 300 && lux <= 500;
      case 'General Work':
        return lux >= 500 && lux <= 750;
      case 'Detailed Work':
        return lux >= 750 && lux <= 1500;
      case 'Relaxation':
        return lux >= 100 && lux <= 300;
      case 'Ambient Lighting':
        return lux >= 50 && lux <= 100;
      case 'Too Dark':
        return lux < 50;
      default:
        return false;
    }
  }

  final lightingData = const [
    {'activity': 'Reading', 'range': '300 - 500 lux'},
    {'activity': 'General Work', 'range': '500 - 750 lux'},
    {'activity': 'Detailed Work', 'range': '750 - 1500 lux'},
    {'activity': 'Relaxation', 'range': '100 - 300 lux'},
    {'activity': 'Ambient Lighting', 'range': '50 - 100 lux'},
    {'activity': 'Too Dark', 'range': '< 50 lux'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A3A2E),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            const Text(
              'Light Meter',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            if (!sensorAvailable)
              const Text(
                "Unable to access ambient light",
                style: TextStyle(color: Colors.red),
              ),

            if (sensorAvailable)
              Column(
                children: [
                  Text(
                    luxValue.toStringAsFixed(0),
                    style: const TextStyle(
                      color: Color(0xFF00FF88),
                      fontSize: 90,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'lux',
                    style: TextStyle(color: Colors.white, fontSize: 22),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    getRecommendation(luxValue),
                    style: const TextStyle(
                      color: Color(0xFF00FF88),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),

            const SizedBox(height: 20),

            // Let table size to its content to avoid excessive empty space
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: buildRecommendationTable(),
            ),
            const SizedBox(height: 16),

            GestureDetector(
              onTap: () {
                setState(() {
                  isActive = !isActive;
                  if (isActive) {
                    startSensor();
                  } else {
                    stopSensor();
                    widget.onStop?.call();
                  }
                });
              },
              child: Container(
                // Responsive width: up to 420px on wide screens, else 90% width
                width: (MediaQuery.of(context).size.width > 600)
                    ? 360
                    : MediaQuery.of(context).size.width * 0.8,
                padding: const EdgeInsets.symmetric(vertical: 14),
                constraints: const BoxConstraints(minHeight: 48),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF88),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Center(
                  child: Text(
                    isActive ? 'Stop Measurement' : 'Start Measurement',
                    style: const TextStyle(
                      color: Color(0xFF1A3A2E),
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget buildRecommendationTable() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF234338),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2D5347)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF2B4B44),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
              border: const Border(
                bottom: BorderSide(color: Color(0xFF2D5347), width: 1),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: Text(
                    'Activity',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Recommended Lux',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...lightingData.map((row) {
            final highlight = isInRange(luxValue, row['activity']!);
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFF2D5347), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row['activity']!,
                      style: TextStyle(
                        color: highlight
                            ? const Color(0xFF00FF88)
                            : Colors.white,
                        fontWeight: highlight
                            ? FontWeight.w700
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row['range']!,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: highlight
                            ? const Color(0xFF00FF88)
                            : Colors.white,
                        fontWeight: highlight
                            ? FontWeight.w700
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
