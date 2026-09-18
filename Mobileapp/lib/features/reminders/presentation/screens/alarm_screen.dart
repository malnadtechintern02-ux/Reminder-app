import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../domain/entities/reminder.dart';
import '../providers/reminder_list_provider.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/theme_provider.dart';
import '../../../../core/services/notification_service.dart';

class AlarmScreen extends ConsumerStatefulWidget {
  final String reminderId;

  const AlarmScreen({
    super.key,
    required this.reminderId,
  });

  @override
  ConsumerState<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends ConsumerState<AlarmScreen> with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _rippleController;
  Timer? _clockTimer;
  Timer? _vibrationTimer;
  DateTime _currentTime = DateTime.now();
  int _selectedSnoozeMinutes = 10;
  bool _isPlaying = false;
  Reminder? _reminder;

  @override
  void initState() {
    super.initState();

    // Enable true full-screen immersive mode (hide Android status/nav bars)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Keep screen on and wake up display immediately
    NotificationService.instance.wakeUpScreen();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAlarm();
    });
  }

  Future<void> _initAlarm() async {
    final list = ref.read(reminderListNotifierProvider).reminders;
    final match = list.where((r) => r.id == widget.reminderId);
    if (match.isNotEmpty) {
      _reminder = match.first;
    } else {
      // Fallback: load directly from repository
      try {
        final repo = ref.read(reminderRepositoryProvider);
        _reminder = await repo.getReminderById(widget.reminderId);
      } catch (e) {
        debugPrint('Error retrieving reminder: $e');
      }
    }

    if (!mounted) return;

    if (_reminder != null) {
      setState(() {
        _selectedSnoozeMinutes = _reminder!.snoozeMinutes > 0 ? _reminder!.snoozeMinutes : 10;
      });
      _startAlarmAudioAndVibration(_reminder!);
    } else {
      // Create a fallback placeholder reminder
      _reminder = Reminder(
        id: widget.reminderId,
        title: 'Alarm',
        scheduledAt: DateTime.now(),
        categoryId: 'general',
        priority: Priority.high,
        isCompleted: false,
        isRepeating: false,
        repeatType: RepeatType.none,
        hasAlarm: true,
        alarmEnabled: true,
        alarmSoundEnabled: true,
        alarmVibrationEnabled: true,
        snoozeMinutes: 10,
        warningEnabled: true,
        createdAt: DateTime.now(),
      );
      _startAlarmAudioAndVibration(_reminder!);
    }
  }

  Future<void> _startAlarmAudioAndVibration(Reminder reminder) async {
    if (!reminder.alarmSoundEnabled && !reminder.hasAlarm && !reminder.alarmEnabled) {
      return;
    }

    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gainTransientExclusive,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {AVAudioSessionOptions.duckOthers},
          ),
        ),
      );

      await _audioPlayer.setReleaseMode(ReleaseMode.loop);

      final prefs = ref.read(sharedPreferencesProvider);
      final globalRingtone = prefs.getString('defaultRingtone') ?? 'morning_breeze';
      final ringtoneId = (reminder.ringtone != null && reminder.ringtone!.isNotEmpty)
          ? reminder.ringtone!
          : globalRingtone;

      if (reminder.alarmSoundEnabled) {
        final isBuiltIn = builtInRingtones.any((r) => r.id == ringtoneId);
        if (isBuiltIn) {
          try {
            await _audioPlayer.play(AssetSource('sounds/$ringtoneId.wav'));
          } catch (_) {
            await _audioPlayer.play(AssetSource('sounds/$ringtoneId.mp3'));
          }
        } else {
          final file = File(ringtoneId);
          if (await file.exists()) {
            try {
              final bytes = await file.readAsBytes();
              await _audioPlayer.play(BytesSource(bytes));
            } catch (_) {
              await _audioPlayer.play(DeviceFileSource(ringtoneId));
            }
          } else {
            await _audioPlayer.play(AssetSource('sounds/morning_breeze.wav'));
          }
        }
        _isPlaying = true;
      }
    } catch (e) {
      debugPrint('Error playing alarm sound in AlarmScreen: $e');
    }

    if (reminder.alarmVibrationEnabled && reminder.vibrationPattern != 'off') {
      _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1200), (timer) {
        HapticFeedback.heavyImpact();
      });
    }
  }

  Future<void> _stopAlarm() async {
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
    if (_isPlaying) {
      try {
        await _audioPlayer.stop();
        _isPlaying = false;
      } catch (e) {
        debugPrint('Error stopping audio: $e');
      }
    }
    // Cancel the notification banner on the device
    await NotificationService.instance.cancelNotification(widget.reminderId);
    // Release keep screen on flags
    await NotificationService.instance.dismissAlarmFlags();
  }

  Future<void> _dismissAlarm() async {
    await _stopAlarm();
    if (_reminder != null) {
      if (_reminder!.isRepeating && _reminder!.repeatType != RepeatType.none) {
        // For repeating reminder, reschedule next occurrence
        await NotificationService.instance.scheduleRepeatingNotification(reminder: _reminder!);
      } else {
        // Mark one-off reminder as completed
        await ref
            .read(reminderListNotifierProvider.notifier)
            .toggleCompletion(_reminder!.id, true);
      }
    }

    if (mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(RoutePaths.reminders);
      }
    }
  }

  Future<void> _snoozeAlarm() async {
    await _stopAlarm();

    if (_reminder != null) {
      final snoozeTarget = DateTime.now().add(Duration(minutes: _selectedSnoozeMinutes));
      final snoozedReminder = _reminder!.copyWith(
        scheduledAt: snoozeTarget,
        isCompleted: false,
      );

      // Schedule the snoozed alarm notification
      await NotificationService.instance.scheduleNotification(reminder: snoozedReminder);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Alarm snoozed for $_selectedSnoozeMinutes minutes'),
            backgroundColor: Colors.blueGrey.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }

    if (mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(RoutePaths.reminders);
      }
    }
  }

  @override
  void dispose() {
    // Restore normal system overlays
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    NotificationService.instance.dismissAlarmFlags();

    _clockTimer?.cancel();
    _vibrationTimer?.cancel();
    _pulseController.dispose();
    _rippleController.dispose();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat('hh:mm');
    final amPmFormat = DateFormat('a');
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');

    final title = _reminder?.title ?? 'Reminder Alarm';
    final description = _reminder?.description;
    final ringtoneName = formatRingtoneName(_reminder?.ringtone);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _dismissAlarm();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1117),
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.3),
              radius: 1.2,
              colors: [
                Color(0xFF1F293D),
                Color(0xFF0F172A),
                Color(0xFF080C14),
              ],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),

                  // Animated Pulsing Bell with Concentric Ripples
                  AnimatedBuilder(
                    animation: _rippleController,
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer Ripple
                          Transform.scale(
                            scale: 1.0 + (_rippleController.value * 0.7),
                            child: Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.amberAccent.withValues(
                                    alpha: ((1.0 - _rippleController.value) * 0.45).clamp(0.0, 1.0),
                                  ),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          // Middle Ripple
                          Transform.scale(
                            scale: 1.0 + (((_rippleController.value + 0.5) % 1.0) * 0.5),
                            child: Container(
                              width: 95,
                              height: 95,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.amber.withValues(
                                    alpha: ((1.0 - ((_rippleController.value + 0.5) % 1.0)) * 0.4).clamp(0.0, 1.0),
                                  ),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          // Center Pulsing Bell
                          ScaleTransition(
                            scale: _pulseAnimation,
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.amber.withValues(alpha: 0.18),
                                border: Border.all(
                                  color: Colors.amber.withValues(alpha: 0.4),
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.amber.withValues(alpha: 0.35),
                                    blurRadius: 36,
                                    spreadRadius: 6,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.notifications_active_rounded,
                                size: 52,
                                color: Colors.amberAccent,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // Digital Clock
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        timeFormat.format(_currentTime),
                        style: const TextStyle(
                          fontSize: 70,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 2,
                          height: 1,
                          shadows: [
                            Shadow(
                              color: Color(0x66F59E0B),
                              blurRadius: 20,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        amPmFormat.format(_currentTime),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.amberAccent.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Date
                  Text(
                    dateFormat.format(_currentTime),
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const Spacer(),

                  // Reminder Title & Details Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.4,
                          ),
                        ),
                        if (description != null && description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            description,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.white.withValues(alpha: 0.75),
                              height: 1.3,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        // Ringtone badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.music_note_rounded, size: 14, color: Colors.amberAccent),
                              const SizedBox(width: 6),
                              Text(
                                ringtoneName,
                                style: const TextStyle(
                                  color: Colors.amberAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Snooze Options Row
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
                        child: Text(
                          'Snooze Duration',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      Row(
                        children: [5, 10, 15, 30].map((mins) {
                          final isSelected = _selectedSnoozeMinutes == mins;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3.0),
                              child: InkWell(
                                onTap: () {
                                  setState(() => _selectedSnoozeMinutes = mins);
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? theme.primaryColor
                                        : Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? theme.primaryColor
                                          : Colors.white.withValues(alpha: 0.15),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${mins}m',
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.white70,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Action Buttons: Snooze & Dismiss
                  Row(
                    children: [
                      // Snooze Button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _snoozeAlarm,
                          icon: const Icon(Icons.snooze_rounded),
                          label: Text('Snooze ($_selectedSnoozeMinutes m)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Dismiss Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _dismissAlarm,
                          icon: const Icon(Icons.alarm_off_rounded),
                          label: const Text('Dismiss'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE53935),
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shadowColor: const Color(0xFFE53935).withValues(alpha: 0.5),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  }
}
