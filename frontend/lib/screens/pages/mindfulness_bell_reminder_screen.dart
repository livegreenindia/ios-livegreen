import 'package:flutter/material.dart';

import '../../models/mindfulness_bell_settings.dart';
import '../../services/mindfulness_bell_scheduler.dart';
import '../../services/mindfulness_bell_settings_service.dart';
import '../../widgets/app_widgets.dart';
import '../../theme/app_theme.dart';

class MindfulnessBellReminderScreen extends StatefulWidget {
  const MindfulnessBellReminderScreen({
    super.key,
    required this.activityTitle,
    required this.activityId,
  });

  final String activityTitle;
  final String activityId;

  @override
  State<MindfulnessBellReminderScreen> createState() =>
      _MindfulnessBellReminderScreenState();
}

class _MindfulnessBellReminderScreenState
    extends State<MindfulnessBellReminderScreen> {
  final MindfulnessBellSettingsService _settingsService =
      MindfulnessBellSettingsService();

  MindfulnessBellSettings _settings = MindfulnessBellSettings.defaults;
  bool _loading = true;
  bool _saving = false;
  bool _reminderRunning = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loadedSettings = await _settingsService.loadSettings();
    final enabled = await _settingsService.isReminderEnabled();

    if (!mounted) {
      return;
    }

    setState(() {
      _settings = loadedSettings;
      _reminderRunning = enabled;
      _loading = false;
    });
  }

  Future<void> _startReminder() async {
    setState(() {
      _saving = true;
    });

    try {
      await _settingsService.saveSettings(_settings);
      await MindfulnessBellScheduler.startRecurringReminder(_settings);
      await _settingsService.setReminderEnabled(true);

      if (!mounted) {
        return;
      }

      setState(() {
        _reminderRunning = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Mindfulness Bell started every ${_settings.interval.label}.',
          ),
          backgroundColor: AppColors.primaryDark,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _stopReminder() async {
    setState(() {
      _saving = true;
    });

    try {
      await MindfulnessBellScheduler.cancelRecurringReminder();
      await _settingsService.setReminderEnabled(false);

      if (!mounted) {
        return;
      }

      setState(() {
        _reminderRunning = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Mindfulness Bell reminder stopped.'),
          backgroundColor: AppColors.primaryDark,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Widget _buildTimePicker(
    BuildContext context,
    String label,
    int minutesFromMidnight,
    ValueChanged<int> onChanged,
  ) {
    final hours = minutesFromMidnight ~/ 60;
    final minutes = minutesFromMidnight % 60;
    final timeString =
        '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            if (!_settings.quietHoursEnabled) {
              return;
            }
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(hour: hours, minute: minutes),
            );
            if (picked != null) {
              onChanged(picked.hour * 60 + picked.minute);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).dividerColor,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  timeString,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Icon(
                  Icons.access_time,
                  size: 20,
                  color: Theme.of(context).iconTheme.color?.withOpacity(0.6),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mindfulness Bell'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.activityTitle,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Configure your recurring reminder and tap Start to begin Practice alerts.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alarm Sound',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        DropdownButtonFormField<AlarmSound>(
                          value: _settings.sound,
                          items: AlarmSound.values
                              .map(
                                (sound) => DropdownMenuItem<AlarmSound>(
                                  value: sound,
                                  child: Text(sound.label),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _settings = _settings.copyWith(sound: value);
                            });
                          },
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Reminder Interval',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        DropdownButtonFormField<ReminderInterval>(
                          value: _settings.interval,
                          items: ReminderInterval.values
                              .map(
                                (interval) =>
                                    DropdownMenuItem<ReminderInterval>(
                                  value: interval,
                                  child: Text(interval.label),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _settings = _settings.copyWith(interval: value);
                            });
                          },
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mute The Bell When',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        SwitchListTile(
                          title: const Text('Flight mode'),
                          value: _settings.muteWhenFlightMode,
                          activeColor: AppColors.primary,
                          onChanged: (value) {
                            setState(() {
                              _settings = _settings.copyWith(
                                muteWhenFlightMode: value,
                              );
                            });
                          },
                        ),
                        SwitchListTile(
                          title: const Text('Silent mode'),
                          value: _settings.muteWhenSilentMode,
                          activeColor: AppColors.primary,
                          onChanged: (value) {
                            setState(() {
                              _settings = _settings.copyWith(
                                muteWhenSilentMode: value,
                              );
                            });
                          },
                        ),
                        SwitchListTile(
                          title: const Text('Do Not Disturb'),
                          value: _settings.muteWhenDoNotDisturb,
                          activeColor: AppColors.primary,
                          onChanged: (value) {
                            setState(() {
                              _settings = _settings.copyWith(
                                muteWhenDoNotDisturb: value,
                              );
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Quiet Hours',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Switch(
                              value: _settings.quietHoursEnabled,
                              activeColor: AppColors.primary,
                              onChanged: (value) {
                                setState(() {
                                  _settings = _settings.copyWith(
                                    quietHoursEnabled: value,
                                  );
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Mute reminders during specific hours',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Opacity(
                          opacity: _settings.quietHoursEnabled ? 1.0 : 0.4,
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildTimePicker(
                                  context,
                                  'From',
                                  _settings.quietHoursStartMinutes,
                                  (minutes) {
                                    if (_settings.quietHoursEnabled) {
                                      setState(() {
                                        _settings = _settings.copyWith(
                                          quietHoursStartMinutes: minutes,
                                        );
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: _buildTimePicker(
                                  context,
                                  'To',
                                  _settings.quietHoursEndMinutes,
                                  (minutes) {
                                    if (_settings.quietHoursEnabled) {
                                      setState(() {
                                        _settings = _settings.copyWith(
                                          quietHoursEndMinutes: minutes,
                                        );
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppPrimaryButton(
                    label: _reminderRunning
                        ? 'Reminder Running'
                        : 'Start Reminder',
                    icon: Icons.notifications_active,
                    isExpanded: true,
                    isLoading: _saving,
                    onPressed: _reminderRunning ? null : _startReminder,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppSecondaryButton(
                    label: 'Stop Reminder',
                    icon: Icons.notifications_off,
                    isExpanded: true,
                    isLoading: _saving,
                    onPressed: _reminderRunning ? _stopReminder : null,
                  ),
                ],
              ),
            ),
    );
  }
}
