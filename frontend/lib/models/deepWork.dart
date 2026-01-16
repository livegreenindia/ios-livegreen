import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';

// Platform channel for DND control
const MethodChannel _dndChannel = MethodChannel('com.livegreen.app/dnd');

// Deep Work Session Screen for LiveGreen
class DeepWorkScreen extends StatelessWidget {
  const DeepWorkScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.only(top: 16.0, bottom: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.psychology,
                          color: const Color(0xFF00D9A3),
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'LiveGreen Deep Work',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Main Content
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    // Title
                    RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                        children: [
                          TextSpan(
                            text: 'Deep Work ',
                            style: TextStyle(color: Colors.white),
                          ),
                          TextSpan(
                            text: 'Session',
                            style: TextStyle(color: Color(0xFF00D9A3)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Subtitle
                    const Text(
                      'To customize your path to flow, please\nselect your current role.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Role Cards
                    RoleCard(
                      icon: Icons.business_center,
                      iconColor: const Color(0xFF00D9A3),
                      title: 'Corporate Professional',
                      description: 'Maximize productivity in the\nworkplace.',
                      imagePath: 'assets/corporate.jpg',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const RoleSelectionScreen(role: 'corporate'),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    RoleCard(
                      icon: Icons.school,
                      iconColor: const Color(0xFF00D9A3),
                      title: 'Academic Student',
                      description: 'Optimize study habits and\nexam focus.',
                      imagePath: 'assets/student.jpg',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const RoleSelectionScreen(role: 'student'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoleCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String imagePath;
  final VoidCallback onTap;

  const RoleCard({
    Key? key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.imagePath,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A3A2E).withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          ),
          child: Row(
            children: [
              // Icon Container
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A4A3E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 32, color: iconColor),
              ),
              const SizedBox(width: 16),
              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.7),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow Icon
              Icon(
                Icons.arrow_forward,
                color: Colors.white.withOpacity(0.5),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoleSelectionScreen extends StatefulWidget {
  final String role;
  const RoleSelectionScreen({Key? key, required this.role}) : super(key: key);

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  late Map<String, TaskCategory> tasks;
  late List<TaskConfig> taskConfigs;
  List<String> completedMissions = []; // Store completed missions locally

  @override
  void initState() {
    super.initState();
    _setupTasksForRole();
    _loadCompletedMissions(); // Load missions on init
  }

  Future<void> _loadCompletedMissions() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      completedMissions = prefs.getStringList('completed_missions') ?? [];
    });
  }

  void _setupTasksForRole() {
    if (widget.role == 'corporate') {
      tasks = {
        'environment': TaskCategory(
          completed: false,
          items: [
            TaskItem(
              id: 'walk',
              label: 'A brief 5 min walk can increase blood flow and alertness',
              checked: false,
            ),
            TaskItem(
              id: 'headphones',
              label: 'Use noise-canceling headphones',
              checked: false,
            ),
            TaskItem(
              id: 'chair',
              label:
                  'Chair Height: Adjust so your feet are flat on the floor and your knees are at a 90-degree angle',
              checked: false,
            ),
            TaskItem(
              id: 'monitor',
              label:
                  'Monitor Position: Set the top of your screen at or slightly below eye level to prevent neck strain',
              checked: false,
            ),
            TaskItem(
              id: 'lighting',
              label: 'Maintain at least above 400 lux lighting',
              checked: false,
            ),
          ],
        ),
        'physical': TaskCategory(
          completed: false,
          items: [
            TaskItem(
              id: 'water',
              label: 'Drink glass of water',
              checked: false,
            ),
            TaskItem(
              id: 'tea',
              label: 'Drink glass of green tea or coffee with no/less sugar',
              checked: false,
            ),
            TaskItem(
              id: 'breathing',
              label: 'Practice Box breathing for 5 minutes',
              checked: false,
            ),
            TaskItem(
              id: 'chocolate',
              label:
                  'Bite a no sugar dark chocolate- improves blood flow to brain',
              checked: false,
            ),
          ],
        ),
        'taskPrep': TaskCategory(
          completed: false,
          items: [
            TaskItem(
              id: 'scope',
              label:
                  'Scope to 100 Minutes: Define a "100-minute object"—a piece of work that can realistically be completed or reach a major milestone in one session',
              checked: false,
            ),
            TaskItem(
              id: 'sessions',
              label:
                  'Micro breaks: Break the tasks into 4 session of 25 minutes session in such a way that tasks are little bit beyond your current skill level to avoid both boredom and anxiety. Take 5 minutes break between the sessions',
              checked: false,
            ),
            TaskItem(
              id: 'context',
              label:
                  'Context Loading: Open every document, browser tab, and dataset you will need before starting the timer',
              checked: false,
            ),
            TaskItem(
              id: 'granular',
              label:
                  'Granular Specificity: Instead of "write presentation," use "complete slides 1–5 with data visualizations"',
              checked: false,
            ),
          ],
        ),
      };

      taskConfigs = [
        TaskConfig(
          key: 'environment',
          title: '1. Environment Preparation',
          description:
              'A brief 5 min walk can increase blood flow and alertness. Use noise-canceling headphones. Adjust chair height so feet are flat and knees at 90°. Set monitor top at/below eye level. Maintain at least 400 lux lighting.',
          buttonText: 'Complete Environment Setup',
        ),
        TaskConfig(
          key: 'physical',
          title: '2. Physical Preparation',
          description:
              'Drink a glass of water. Drink green tea or coffee with no/less sugar. Practice Box breathing for 5 minutes. Bite no-sugar dark chocolate - improves blood flow to brain.',
          buttonText: 'Complete Physical Prep',
        ),
        TaskConfig(
          key: 'taskPrep',
          title: '3. Task Preparation',
          description:
              'Scope to 100 minutes with realistic milestones. Break into 4 x 25min sessions slightly beyond skill level. Take 5-min breaks. Open all documents, tabs, datasets. Use granular specificity.',
          buttonText: 'Confirm Task Plan',
        ),
      ];
    } else {
      // Academic Student tasks - different from corporate
      tasks = {
        'environment': TaskCategory(
          completed: false,
          items: [
            TaskItem(
              id: 'walk',
              label: 'A brief 5 min walk can increase blood flow and alertness',
              checked: false,
            ),
            TaskItem(
              id: 'headphones',
              label: 'Use noise-canceling headphones',
              checked: false,
            ),
            TaskItem(
              id: 'chair',
              label:
                  'Chair Height: Adjust so your feet are flat on the floor and your knees are at a 90-degree angle',
              checked: false,
            ),
            TaskItem(
              id: 'monitor',
              label:
                  'Monitor Position: Set the top of your screen at or slightly below eye level to prevent neck strain',
              checked: false,
            ),
            TaskItem(
              id: 'lighting',
              label: 'Maintain at least above 400 lux lighting',
              checked: false,
            ),
          ],
        ),
        'physical': TaskCategory(
          completed: false,
          items: [
            TaskItem(
              id: 'water',
              label: 'Drink glass of water',
              checked: false,
            ),
            TaskItem(
              id: 'tea',
              label: 'Drink glass of green tea or coffee with no/less sugar',
              checked: false,
            ),
            TaskItem(
              id: 'breathing',
              label: 'Practice Box breathing for 5 minutes',
              checked: false,
            ),
            TaskItem(
              id: 'chocolate',
              label:
                  'Bite a no sugar dark chocolate- improves blood flow to brain',
              checked: false,
            ),
          ],
        ),
        'taskPrep': TaskCategory(
          completed: false,
          items: [
            TaskItem(
              id: 'scope',
              label:
                  'Scope to 100 Minutes: Define a "100-minute object"—a piece of work that can realistically be completed or reach a major milestone in one session',
              checked: false,
            ),
            TaskItem(
              id: 'flow',
              label:
                  'Flow object: Define a specific outcome for the 90 minutes. Instead of "work on thesis," use "draft the methodology section for experiment B" or "synthesize chapter 4 and complete assignments"',
              checked: false,
            ),
            TaskItem(
              id: 'sessions',
              label:
                  'Micro breaks: Break the tasks into 4 session of 25 minutes session in such a way that tasks are little bit beyond your current skill level to avoid both boredom and anxiety. Take 5 minutes break between the sessions',
              checked: false,
            ),
            TaskItem(
              id: 'context',
              label:
                  'Context Loading: Open every document, book, browser tab, and dataset you will need before starting the timer',
              checked: false,
            ),
          ],
        ),
      };

      taskConfigs = [
        TaskConfig(
          key: 'environment',
          title: '1. Study Environment Setup',
          description:
              'A brief 5 min walk can increase blood flow and alertness. Use noise-canceling headphones. Adjust chair height so feet are flat and knees at 90°. Set monitor top at/below eye level. Maintain at least 400 lux lighting.',
          buttonText: 'Complete Environment Setup',
        ),
        TaskConfig(
          key: 'physical',
          title: '2. Physical Preparation',
          description:
              'Drink a glass of water. Drink green tea or coffee with no/less sugar. Practice Box breathing for 5 minutes. Bite no-sugar dark chocolate - improves blood flow to brain.',
          buttonText: 'Complete Physical Prep',
        ),
        TaskConfig(
          key: 'taskPrep',
          title: '3. Study Task Planning',
          description:
              'Scope to 100 minutes with realistic milestones. Define specific flow object for study. Break into 4 x 25min sessions beyond skill level. Take 5-min breaks. Open all books, documents, tabs, datasets.',
          buttonText: 'Confirm Study Plan',
        ),
      ];
    }
  }

  void handleItemCheck(String taskKey, String itemId) {
    setState(() {
      final task = tasks[taskKey];
      if (task == null) return;

      final itemIndex = task.items.indexWhere((i) => i.id == itemId);

      if (itemIndex != -1) {
        final item = task.items[itemIndex];
        // Create a new item with toggled checked state
        task.items[itemIndex] = item.copyWith(checked: !item.checked);
      }
    });
  }

  void handleCompleteTask(String taskKey) {
    final task = tasks[taskKey] ?? TaskCategory(completed: false, items: []);
    final allChecked = task.items.every((item) => item.checked);

    if (allChecked) {
      setState(() {
        if (tasks[taskKey] != null) {
          tasks[taskKey]!.completed = true;
        }
      });
    }
  }

  bool isTaskUnlocked(int index) {
    final taskKeys = ['environment', 'physical', 'taskPrep'];
    if (index == 0) return true;
    final previousTask = tasks[taskKeys[index - 1]];
    return previousTask?.completed ?? false;
  }

  int getCompletedCount() {
    return tasks.values.where((t) => t.completed).length;
  }

  bool get allTasksCompleted => getCompletedCount() == 3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D2818),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2818),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF00D9A3)),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Pre-Flow Protocol',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          // Achievement Button
          IconButton(
            onPressed: () {
              // Show completed missions dialog with real-time data
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Your Achievements'),
                  content: SizedBox(
                    width: double.maxFinite,
                    height: 200,
                    child: completedMissions.isEmpty
                        ? Text(
                            'No missions completed yet. Start your first focus session!',
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '🏆 Completed Missions (${completedMissions.length}):',
                                style: TextStyle(
                                  color: Color(0xFF00D9A3),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 12),
                              ...completedMissions
                                  .take(4)
                                  .map(
                                    (mission) => Padding(
                                      padding: EdgeInsets.only(bottom: 4),
                                      child: Text('• $mission'),
                                    ),
                                  )
                                  .toList(),
                            ],
                          ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Great!'),
                    ),
                  ],
                ),
              );
            },
            icon: Icon(Icons.emoji_events, color: Color(0xFF00D9A3)),
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TimerScreen()),
              );
            },
            child: const Text(
              'Skip',
              style: TextStyle(color: Color(0xFF00D9A3), fontSize: 16),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Progress
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'READINESS LEVEL',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          '${((getCompletedCount() / 3) * 100).toInt()}%',
                          style: const TextStyle(
                            color: Color(0xFF00D9A3),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: getCompletedCount() / 3,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF00D9A3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${getCompletedCount()}/3 Steps Completed',
                        style: TextStyle(color: Colors.grey[500], fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),

              // Play Button
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFF00D9A3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Color(0xFF0D2818),
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),

              // Tasks
              ...taskConfigs.asMap().entries.map((entry) {
                final index = entry.key;
                final config = entry.value;
                final task =
                    tasks[config.key] ??
                    TaskCategory(completed: false, items: []);
                final unlocked = isTaskUnlocked(index);
                final allItemsChecked = task.items.every(
                  (item) => item.checked,
                );

                return Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  child: Stack(
                    children: [
                      // Lock Icon
                      if (!unlocked)
                        Positioned(
                          left: -12,
                          top: 0,
                          child: Icon(
                            Icons.lock,
                            color: Colors.grey[600],
                            size: 20,
                          ),
                        ),

                      // Task Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: task.completed
                                ? const Color(0xFF00D9A3).withOpacity(0.5)
                                : unlocked
                                ? const Color(0xFF00D9A3)
                                : Colors.grey[700]!,
                            width: 2,
                          ),
                          color: task.completed
                              ? const Color(0xFF00D9A3).withOpacity(0.1)
                              : unlocked
                              ? const Color(0xFF00D9A3).withOpacity(0.05)
                              : Colors.grey[800]!.withOpacity(0.3),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  config.title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                if (task.completed)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00D9A3),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      '✓ DONE',
                                      style: TextStyle(
                                        color: Color(0xFF0D2818),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                else if (unlocked)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00D9A3),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'ACTIVE',
                                      style: TextStyle(
                                        color: Color(0xFF0D2818),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Description
                            Text(
                              config.description,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Checklist Items
                            ...task.items.map((item) {
                              return GestureDetector(
                                onTap: unlocked && !task.completed
                                    ? () => handleItemCheck(config.key, item.id)
                                    : null,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.grey[600]!,
                                            width: 2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          color: item.checked
                                              ? const Color(0xFF00D9A3)
                                              : Colors.transparent,
                                        ),
                                        child: item.checked
                                            ? const Icon(
                                                Icons.check,
                                                color: Color(0xFF0D2818),
                                                size: 16,
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          item.label,
                                          style: TextStyle(
                                            color: item.checked
                                                ? Colors.white70
                                                : Colors.white,
                                            fontSize: 14,
                                            decoration: item.checked
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),

                            const SizedBox(height: 16),

                            // Complete Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed:
                                    (unlocked &&
                                        allItemsChecked &&
                                        !task.completed)
                                    ? () => handleCompleteTask(config.key)
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: task.completed
                                      ? const Color(0xFF00D9A3).withOpacity(0.3)
                                      : allItemsChecked && unlocked
                                      ? const Color(0xFF00D9A3)
                                      : Colors.grey[700]!.withOpacity(0.5),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  task.completed
                                      ? '✓ Completed'
                                      : config.buttonText,
                                  style: TextStyle(
                                    color: task.completed
                                        ? const Color(0xFF00D9A3)
                                        : allItemsChecked && unlocked
                                        ? const Color(0xFF0D2818)
                                        : Colors.grey[500],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),

              // Enter Flow State Button
              Container(
                margin: const EdgeInsets.only(top: 32, bottom: 24),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: allTasksCompleted
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const TimerScreen(),
                                  ),
                                );
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: allTasksCompleted
                              ? const Color(0xFF00D9A3)
                              : Colors.grey[800],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          '⚡ Enter Flow State',
                          style: TextStyle(
                            color: allTasksCompleted
                                ? const Color(0xFF0D2818)
                                : Colors.grey[600],
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      allTasksCompleted
                          ? 'Ready to begin!'
                          : 'COMPLETE ALL STEPS TO UNLOCK',
                      style: TextStyle(color: Colors.grey[500], fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TaskCategory {
  bool completed;
  List<TaskItem> items;

  TaskCategory({required this.completed, required this.items});
}

class TaskItem {
  String id;
  String label;
  bool checked;

  TaskItem({required this.id, required this.label, required this.checked});

  TaskItem copyWith({String? id, String? label, bool? checked}) {
    return TaskItem(
      id: id ?? this.id,
      label: label ?? this.label,
      checked: checked ?? this.checked,
    );
  }
}

class TaskConfig {
  String key;
  String title;
  String description;
  String buttonText;

  TaskConfig({
    required this.key,
    required this.title,
    required this.description,
    required this.buttonText,
  });
}

class CompletionScreen extends StatelessWidget {
  final String mission;
  final String timestamp;

  const CompletionScreen({
    Key? key,
    required this.mission,
    required this.timestamp,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1a2f1a),
      appBar: AppBar(
        backgroundColor: Color(0xFF1a2f1a),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFF90EE90)),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        centerTitle: true,
        title: Text(
          'Mission Complete!',
          style: TextStyle(
            color: Color(0xFF90EE90),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Large circular progress indicator
              Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF90EE90).withOpacity(0.2),
                      Color(0xFF90EE90).withOpacity(0.1),
                    ],
                  ),
                  border: Border.all(
                    color: Color(0xFF90EE90).withOpacity(0.6),
                    width: 3,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.emoji_events,
                        color: Color(0xFF90EE90),
                        size: 60,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '100%',
                        style: TextStyle(
                          color: Color(0xFF90EE90),
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'Mission Complete!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF90EE90),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Great job! You\'ve successfully completed your focus session.',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF90EE90).withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF90EE90).withOpacity(0.1),
                      Color(0xFF90EE90).withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Color(0xFF90EE90).withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mission Details',
                      style: TextStyle(
                        color: Color(0xFF90EE90),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.task_alt,
                          color: Color(0xFF90EE90),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            mission,
                            style: TextStyle(
                              color: Color(0xFF90EE90).withOpacity(0.9),
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          color: Color(0xFF90EE90),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timestamp,
                          style: TextStyle(
                            color: Color(0xFF90EE90).withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.popUntil(context, (route) => route.isFirst);
                      },
                      icon: Icon(Icons.home, color: Color(0xFF1a2f1a)),
                      label: Text(
                        'New Session',
                        style: TextStyle(
                          color: Color(0xFF1a2f1a),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF90EE90),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await _shareMission();
                        Navigator.pop(context);
                      },
                      icon: Icon(Icons.share, color: Color(0xFF1a2f1a)),
                      label: Text(
                        'Share',
                        style: TextStyle(
                          color: Color(0xFF1a2f1a),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF90EE90),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareMission() async {
    try {
      await Share.share(
        'I just completed a focus session on LiveGreen: "$mission" 🎯\n\n'
        'Completed 4 focus sessions using binaural beats for deep concentration! 🧠✨\n\n'
        'Join me on LiveGreen: https://play.google.com/store/apps/details?id=com.livegreen.app',
        subject: 'LiveGreen Focus Session Complete',
      );
    } catch (e) {
      print('Error sharing mission: $e');
    }
  }
}

class TimerScreen extends StatefulWidget {
  const TimerScreen({Key? key}) : super(key: key);

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  static const int workSeconds = 1500; // 25 minutes (25 * 60)
  static const int breakSeconds = 300; // 5 minutes (5 * 60)
  int remainingSeconds = workSeconds;
  Timer? timer;
  bool isRunning = false;
  bool isPaused = false;
  bool isBreakTime = false;
  int currentSession = 1;
  static const int totalSessions = 4;
  final TextEditingController _missionController = TextEditingController();
  List<String> completedMissions = [];

  // Notification blocker
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool notificationsBlocked = false;
  int? originalDndMode; // Store original DND mode

  // Audio players
  final AudioPlayer _backgroundMusicPlayer = AudioPlayer();
  final AudioPlayer _bellSoundPlayer = AudioPlayer();
  bool isAudioMuted = false;

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    _loadCompletedMissions();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Request notification permissions
    await _requestNotificationPermission();
  }

  Future<void> _requestNotificationPermission() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidImplementation != null) {
      final bool? granted = await androidImplementation
          .requestNotificationsPermission();
      print('Notification permission granted: $granted');
    }

    // Request notification listener permission
    if (Platform.isAndroid) {
      await _requestNotificationListenerPermission();
    }
  }

  Future<void> _requestNotificationListenerPermission() async {
    try {
      // Check if service is already enabled first
      final serviceIntent = AndroidIntent(
        action: 'android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS',
      );

      // Try to start our service (it will only start if not already running)
      final startServiceIntent = AndroidIntent(
        action: 'android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS',
        package: 'com.livegreen.app',
      );

      // Only open settings if service is not enabled
      final prefs = await SharedPreferences.getInstance();
      final blockingEnabled =
          prefs.getBool('notification_blocking_enabled') ?? false;

      if (!blockingEnabled) {
        await serviceIntent.launch();
        await startServiceIntent.launch();

        // Show dialog to guide user
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Enable Notification Blocking'),
              content: const Text(
                'Please enable "LiveGreen" in Notification Access settings to block app notifications during focus sessions. Phone calls will still work.\n\nAfter enabling, restart the app for changes to take effect.',
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    // After user enables permission, refresh the service
                    await _refreshNotificationService();
                  },
                  child: const Text('Got it'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      print('Error setting up notification listener: $e');
    }
  }

  // Check if notification listener permission is granted
  Future<bool> _isNotificationListenerPermissionGranted() async {
    try {
      if (Platform.isAndroid) {
        // For a more reliable check, we'll try to enable blocking and see if it works
        // This is a workaround since Flutter doesn't have a direct way to check
        final prefs = await SharedPreferences.getInstance();

        // Check if we've successfully enabled blocking before
        final hasWorkedBefore =
            prefs.getBool('notification_listener_has_worked') ?? false;

        // If it worked before, assume permission is still granted
        if (hasWorkedBefore) {
          return true;
        }

        // Otherwise, we'll need to user to grant permission
        return false;
      }
      return false;
    } catch (e) {
      print('Error checking notification listener permission: $e');
      return false;
    }
  }

  // Refresh notification service connection
  Future<void> _refreshNotificationService() async {
    try {
      // Force the service to reconnect by toggling the blocking state
      final prefs = await SharedPreferences.getInstance();
      final currentState =
          prefs.getBool('notification_blocking_enabled') ?? false;

      // Turn off briefly
      await prefs.setBool('notification_blocking_enabled', false);
      await Future.delayed(const Duration(milliseconds: 100));

      // Turn back on
      await prefs.setBool('notification_blocking_enabled', currentState);

      // Mark that the listener has worked
      await prefs.setBool('notification_listener_has_worked', true);

      print('Notification service refreshed - blocking state: $currentState');

      // Send a test notification to verify the service is working
      await _sendTestNotification();
    } catch (e) {
      print('Error refreshing notification service: $e');
    }
  }

  // Send a test notification to verify the service is working
  Future<void> _sendTestNotification() async {
    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'livegreen_deepwork_channel',
            'LiveGreen Deep Work Notifications',
            channelDescription:
                'Notifications from LiveGreen Deep Work sessions',
            importance: Importance.high,
            priority: Priority.high,
          );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
      );

      await flutterLocalNotificationsPlugin.show(
        1,
        'Test Notification',
        'This is a test to verify notification blocking is working',
        notificationDetails,
      );

      print('Test notification sent');
    } catch (e) {
      print('Error sending test notification: $e');
    }
  }

  Future<void> _blockNotifications() async {
    if (!notificationsBlocked) {
      try {
        // Store current DND mode
        originalDndMode = await _getCurrentDndMode();

        // Enable DND mode (Priority only - blocks notifications but allows calls)
        await _setDndMode(
          1,
        ); // 1 = INTERRUPTION_FILTER_PRIORITY (priority only, allows calls)

        setState(() {
          notificationsBlocked = true;
        });

        print(
          'Focus mode activated - DND enabled (priority only - calls allowed)',
        );
      } catch (e) {
        print('Error enabling DND: $e');
      }
    }
  }

  Future<void> _unblockNotifications() async {
    if (notificationsBlocked) {
      try {
        // Restore original DND mode
        if (originalDndMode != null) {
          await _setDndMode(originalDndMode!);
          originalDndMode = null;
        } else {
          // If we don't know the original mode, turn off DND
          await _setDndMode(0); // 0 = INTERRUPTION_FILTER_ALL (no DND)
        }

        setState(() {
          notificationsBlocked = false;
        });

        print('Focus mode deactivated - DND disabled');
      } catch (e) {
        print('Error disabling DND: $e');
      }
    }
  }

  // Get current DND mode
  Future<int> _getCurrentDndMode() async {
    try {
      final int? mode = await _dndChannel.invokeMethod<int>('getDndMode');
      return mode ?? 0;
    } catch (e) {
      print('Error getting current DND mode: $e');
      return 0;
    }
  }

  // Set DND mode
  Future<void> _setDndMode(int mode) async {
    try {
      await _dndChannel.invokeMethod<int>('setDndMode', {'mode': mode});
      print('DND mode set to: $mode');

      // Store mode in SharedPreferences for tracking
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('current_dnd_mode', mode);
    } catch (e) {
      print('Error setting DND mode: $e');
      // Fallback: open DND settings for manual control
      final intent = AndroidIntent(
        action: 'android.settings.ZEN_MODE_SETTINGS',
      );
      await intent.launch();
    }
  }

  Future<void> _loadCompletedMissions() async {
    final prefs = await SharedPreferences.getInstance();
    final missions = prefs.getStringList('completed_missions') ?? [];
    setState(() {
      completedMissions = missions;
    });
  }

  Future<void> _saveMissionToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('completed_missions', completedMissions);
  }

  @override
  void dispose() {
    timer?.cancel();
    _missionController.dispose();
    _backgroundMusicPlayer.dispose();
    _bellSoundPlayer.dispose();
    super.dispose();
  }

  Future<void> _playBackgroundMusic() async {
    if (isAudioMuted) {
      print('🔇 Audio is muted, not playing background music');
      return;
    }

    try {
      // Stop any currently playing music first
      await _backgroundMusicPlayer.stop();

      // Use Theta Pure 40 Hz Binaural Beats as background music
      await _backgroundMusicPlayer.setReleaseMode(ReleaseMode.loop);
      await _backgroundMusicPlayer.setVolume(1.0); // Maximum volume

      print('=== Playing Theta Pure 40 Hz Background Music ===');
      print('🔊 Volume set to 100%');
      print('🎵 Attempting to play local file...');

      // Try your local Theta Pure 40 Hz file first
      try {
        await _backgroundMusicPlayer.play(
          AssetSource(
            'audio/Pure 40 HZ Binaural Beats The Frequency for FOCUS, MEMORY, and CONCENTRATION - Be Inspired  STUDIO.mp3',
          ),
        );
        print('✅ Theta Pure 40 Hz local file started successfully');
        print('🎵 Playing: Theta Pure 40 Hz Binaural Beats');
        print('🔊 Volume: 100%');
      } catch (e) {
        print('❌ Theta Pure 40 Hz local file failed: $e');
        print('🔄 Trying online fallback...');
        // Fallback to online sources
        try {
          await _backgroundMusicPlayer.play(
            UrlSource(
              'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
            ),
          );
          print('✅ Online fallback music started (not Theta Pure 40 Hz)');
        } catch (e2) {
          print('❌ All audio sources failed: $e2');
          print('🚫 No music will play');
        }
      }
    } catch (e) {
      print('❌ Error setting up background music: $e');
    }
  }

  Future<void> _toggleAudio() async {
    setState(() {
      isAudioMuted = !isAudioMuted;
    });

    if (isAudioMuted) {
      await _stopBackgroundMusic();
      print('🔇 Audio muted');
    } else {
      await _playBackgroundMusic();
      print('🔊 Audio unmuted');
    }
  }

  Future<void> _playPreviewMusic() async {
    if (isAudioMuted) {
      print('🔇 Audio is muted, not playing preview music');
      return;
    }

    try {
      await _bellSoundPlayer.setVolume(0.8);
      await _bellSoundPlayer.setReleaseMode(
        ReleaseMode.release,
      ); // Play once, not loop

      print('=== Playing Preview Music (once) ===');

      // Try your local preview.mp3 file first
      try {
        await _bellSoundPlayer.play(AssetSource('audio/preview.mp3'));
        print('✅ Preview music local file started successfully');
        print('🎵 Playing: Preview Music (once)');
      } catch (e) {
        print('❌ Preview music local file failed: $e');
        // Fallback to online sources
        try {
          await _bellSoundPlayer.play(
            UrlSource(
              'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
            ),
          );
          print('✅ Online fallback music started (not preview music)');
        } catch (e2) {
          print('❌ All preview music sources failed: $e2');
        }
      }
    } catch (e) {
      print('❌ Error playing preview music: $e');
    }
  }

  Future<void> _stopBackgroundMusic() async {
    try {
      await _backgroundMusicPlayer.stop();
    } catch (e) {
      print('Error stopping background music: $e');
    }
  }

  Future<void> _playBellSound() async {
    try {
      await _bellSoundPlayer.setVolume(0.9); // Higher volume for bell

      print('Attempting to play bell sound...');

      // Use online bell sound since local file is placeholder
      await _bellSoundPlayer.play(
        UrlSource('https://www.soundjay.com/misc/sounds/bell-ringing-05.mp3'),
      );
      print('Bell sound played successfully');
    } catch (e) {
      print('Error playing bell sound: $e');
      // Try a different online source
      try {
        await _bellSoundPlayer.play(
          UrlSource('https://www.fesliyanstudios.com/play-mp3/387'),
        );
        print('Alternative bell sound played successfully');
      } catch (e2) {
        print('Alternative bell also failed: $e2');
      }
    }
  }

  void _startTimer() async {
    print('=== Starting Timer ===');

    setState(() {
      isRunning = true;
      isPaused = false;
    });

    // Block notifications when timer starts
    await _blockNotifications();

    print('About to start background music...');
    await _playBackgroundMusic(); // Start background music

    print('Starting timer countdown...');
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds > 0) {
        setState(() {
          remainingSeconds--;
        });
        if (remainingSeconds % 10 == 0) {
          print('Timer: $remainingSeconds seconds remaining');
        }
      } else {
        print('Session completed!');
        _handleSessionComplete();
      }
    });
  }

  void _handleSessionComplete() async {
    timer?.cancel();

    if (isBreakTime) {
      // Break completed, start next work session
      setState(() {
        isBreakTime = false;
        remainingSeconds = workSeconds;
      });

      // Re-block notifications when work session resumes
      await _blockNotifications();

      if (currentSession > totalSessions) {
        // All sessions completed - reset to session 1 AND navigate to completion
        _stopBackgroundMusic();
        _saveMission();
        _navigateToCompletion();
        await _unblockNotifications(); // Unblock notifications on completion
        setState(() {
          currentSession = 1;
          isBreakTime = false;
          remainingSeconds = workSeconds;
          isRunning = false;
          isPaused = false;
          _missionController.clear();
        });
      } else {
        // Start next work session - switch back to Theta Pure 40 Hz
        print('🎵 Starting next work session with Theta Pure 40 Hz');
        _playBackgroundMusic();
        _startTimer();
      }
    } else {
      // Work session completed
      // Sessions 1-3 completed, start break. Session 4 goes to completion.
      if (currentSession < totalSessions) {
        setState(() {
          currentSession++;
          isBreakTime = true;
          remainingSeconds = breakSeconds;
        });

        // Unblock notifications during break
        await _unblockNotifications();

        _playPreviewMusic(); // Play preview music when break starts
        _startTimer();
      } else {
        // Session 4 completed - go to completion
        _stopBackgroundMusic();
        _saveMission();
        _navigateToCompletion();
        await _unblockNotifications(); // Unblock notifications on completion
        setState(() {
          currentSession = 1;
          isBreakTime = false;
          remainingSeconds = workSeconds;
          isRunning = false;
          isPaused = false;
          _missionController.clear();
        });
      }
    }
  }

  void _pauseTimer() {
    timer?.cancel();
    setState(() {
      isPaused = true;
    });
    _stopBackgroundMusic(); // Stop music when paused
  }

  void _resumeTimer() {
    setState(() {
      isPaused = false;
    });
    _playBackgroundMusic(); // Resume music when resumed

    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds > 0) {
        setState(() {
          remainingSeconds--;
        });
      } else {
        _handleSessionComplete();
      }
    });
  }

  void _resetTimer() async {
    timer?.cancel();
    _stopBackgroundMusic();
    await _unblockNotifications(); // Unblock notifications when reset
    setState(() {
      isRunning = false;
      isPaused = false;
      isBreakTime = false;
      currentSession = 1;
      remainingSeconds = workSeconds;
      _missionController.clear();
    });
  }

  void _stopTimer() {
    timer?.cancel();
    _stopBackgroundMusic(); // Stop music when stopped
    setState(() {
      isRunning = false;
      isPaused = false;
      isBreakTime = false;
      currentSession = 1;
      remainingSeconds = workSeconds;
    });
  }

  void _navigateToCompletion() {
    String mission = _missionController.text.trim();
    String timestamp = _formatDayTime();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CompletionScreen(mission: mission, timestamp: timestamp),
      ),
    );
  }

  void _showMissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Define Your Mission'),
        content: TextField(
          controller: _missionController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g., Complete the Q3 Report Draft...',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startTimer();
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  void _saveMission() {
    if (_missionController.text.trim().isNotEmpty) {
      String mission =
          "${_missionController.text.trim()} - ${_formatDayTime()}";
      setState(() {
        completedMissions.add(mission);
      });
      _saveMissionToStorage(); // Save to persistent storage
      _missionController.clear();
    }
  }

  String _formatDayTime() {
    DateTime now = DateTime.now();
    List<String> days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    List<String> months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    String dayName = days[now.weekday - 1];
    String monthName = months[now.month - 1];
    return "$dayName $monthName ${now.day}, ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }

  void _showEmptyRequirementDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mission Required'),
        content: const Text(
          'Please enter your mission before starting the focus session.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Widget _buildDotTimer() {
    int totalDots = 60; // 60 dots around the circle
    int currentTotalSeconds = isBreakTime ? breakSeconds : workSeconds;
    int completedDots =
        ((currentTotalSeconds - remainingSeconds) /
                currentTotalSeconds *
                totalDots)
            .round();

    return Stack(
      children: [
        // Dots around the circle
        ...List.generate(totalDots, (index) {
          double angle = (index * 360 / totalDots) * (3.14159 / 180);
          double radius = 100;
          double x = radius * cos(angle);
          double y = radius * sin(angle);

          return Positioned(
            left: 125 + x - 4, // Center (125) - dot radius (4)
            top: 125 + y - 4, // Center (125) - dot radius (4)
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index < completedDots
                    ? (isBreakTime ? Colors.orange : Color(0xFF90EE90))
                    : (isBreakTime
                          ? Colors.orange.withOpacity(0.3)
                          : Color(0xFF90EE90).withOpacity(0.3)),
              ),
            ),
          );
        }),
        // Time digits in the center
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _formatTime(remainingSeconds),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: isBreakTime ? Colors.orange : Color(0xFF90EE90),
                ),
              ),
              SizedBox(height: 8),
              Text(
                isBreakTime ? 'BREAK TIME' : 'FOCUS TIME',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isBreakTime ? Colors.orange : Color(0xFF90EE90),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Session $currentSession of $totalSessions',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1a2f1a), // Dark green background
      appBar: AppBar(
        backgroundColor: Color(0xFF1a2f1a),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFF90EE90)),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        centerTitle: true,
        title: Text(
          'Deep Work Session',
          style: TextStyle(
            color: Color(0xFF90EE90), // Light green
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                'Ready for Flow?',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF90EE90),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Define your specific outcome for this 30-second block.',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF90EE90).withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Color(0xFF90EE90).withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MISSION',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF90EE90).withOpacity(0.7),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _missionController,
                      style: TextStyle(fontSize: 16, color: Color(0xFF90EE90)),
                      decoration: InputDecoration(
                        hintText: 'e.g., Complete the Q3 Report Draft...',
                        hintStyle: TextStyle(
                          color: Color(0xFF90EE90).withOpacity(0.6),
                        ),
                        border: InputBorder.none,
                      ),
                      maxLines: 2,
                      onSubmitted: (value) {
                        print('Mission submitted: "$value"');
                        if (value.trim().isNotEmpty) {
                          print('Starting timer with mission: ${value.trim()}');
                          _startTimer();
                        } else {
                          print('Mission is empty, not starting timer');
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Container(
                width: 250,
                height: 250,
                child: Center(child: _buildDotTimer()),
              ),
              const SizedBox(height: 40),
              // Audio Controls - Always show mute and pause buttons when timer is running
              if (isRunning)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Pause/Resume Button
                    ElevatedButton.icon(
                      onPressed: isPaused ? _resumeTimer : _pauseTimer,
                      icon: Icon(
                        isPaused ? Icons.play_arrow : Icons.pause,
                        color: Color(0xFF1a2f1a),
                      ),
                      label: Text(
                        isPaused ? 'Resume' : 'Pause',
                        style: TextStyle(
                          color: Color(0xFF1a2f1a),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF90EE90),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Mute/Unmute Button
                    ElevatedButton.icon(
                      onPressed: _toggleAudio,
                      icon: Icon(
                        isAudioMuted ? Icons.volume_off : Icons.volume_up,
                        color: Color(0xFF1a2f1a),
                      ),
                      label: Text(
                        isAudioMuted ? 'Unmute' : 'Mute',
                        style: TextStyle(
                          color: Color(0xFF1a2f1a),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isAudioMuted
                            ? Colors.red
                            : Colors.green,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              // Reset Button
              ElevatedButton.icon(
                onPressed: _resetTimer,
                icon: Icon(Icons.refresh, color: Color(0xFF1a2f1a)),
                label: Text(
                  'Reset',
                  style: TextStyle(
                    color: Color(0xFF1a2f1a),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Audio Controls - Show only mute button when timer is not running
              if (!isRunning)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Mute/Unmute Button
                    ElevatedButton.icon(
                      onPressed: _toggleAudio,
                      icon: Icon(
                        isAudioMuted ? Icons.volume_off : Icons.volume_up,
                        color: Color(0xFF1a2f1a),
                      ),
                      label: Text(
                        isAudioMuted ? 'Unmute' : 'Mute',
                        style: TextStyle(
                          color: Color(0xFF1a2f1a),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isAudioMuted
                            ? Colors.red
                            : Colors.green,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              // Binaural beats info text
              Text(
                'Binaural beats music helps you to attain deep focus.',
                style: TextStyle(
                  color: Color(0xFF90EE90).withOpacity(0.7),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (!isRunning)
                ElevatedButton.icon(
                  onPressed: () {
                    if (_missionController.text.trim().isNotEmpty) {
                      _startTimer();
                    } else {
                      _showEmptyRequirementDialog();
                    }
                  },
                  icon: Icon(Icons.play_arrow, color: Color(0xFF1a2f1a)),
                  label: Text(
                    'Start Focus Block',
                    style: TextStyle(
                      color: Color(0xFF1a2f1a),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF90EE90),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              if (!isRunning)
                Text(
                  'Session will lock for 30 seconds.',
                  style: TextStyle(
                    color: Color(0xFF90EE90).withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              const SizedBox(height: 24),
              if (completedMissions.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF90EE90).withOpacity(0.1),
                        Color(0xFF90EE90).withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Color(0xFF90EE90).withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF90EE90).withOpacity(0.1),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.emoji_events,
                            color: Color(0xFF90EE90),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Accomplished',
                            style: TextStyle(
                              color: Color(0xFF90EE90),
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 150,
                        child: ListView.builder(
                          itemCount: completedMissions.length,
                          itemBuilder: (context, index) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Color(0xFF90EE90).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Color(0xFF90EE90).withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    child: Icon(
                                      Icons.check_circle,
                                      color: Color(0xFF90EE90),
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      completedMissions[index],
                                      style: TextStyle(
                                        color: Color(
                                          0xFF90EE90,
                                        ).withOpacity(0.9),
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 50), // Extra space at bottom
            ],
          ),
        ),
      ),
    );
  }
}
