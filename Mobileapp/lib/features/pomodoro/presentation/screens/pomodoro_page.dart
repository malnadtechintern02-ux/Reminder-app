import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/notification_service.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../data/pomodoro_repository.dart';

enum PomodoroMode {
  work,
  shortBreak,
  longBreak,
}

class PomodoroPage extends ConsumerStatefulWidget {
  const PomodoroPage({super.key});

  @override
  ConsumerState<PomodoroPage> createState() => _PomodoroPageState();
}

class _PomodoroPageState extends ConsumerState<PomodoroPage> {
  Timer? _timer;
  late int _remainingSeconds;
  late int _totalDurationSeconds;
  bool _isRunning = false;
  PomodoroMode _currentMode = PomodoroMode.work;
  int _currentCycle = 1; // 1 to 4
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final settings = ref.read(settingsNotifierProvider);
      _totalDurationSeconds = settings.workDuration * 60;
      _remainingSeconds = _totalDurationSeconds;
      _initialized = true;
    }
  }

  void _start() {
    if (_isRunning) return;

    setState(() => _isRunning = true);

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _timer?.cancel();
        setState(() => _isRunning = false);
        _handleSessionCompleted();
      }
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _reset() {
    _timer?.cancel();
    final settings = ref.read(settingsNotifierProvider);
    setState(() {
      _isRunning = false;
      _currentMode = PomodoroMode.work;
      _currentCycle = 1;
      _totalDurationSeconds = settings.workDuration * 60;
      _remainingSeconds = _totalDurationSeconds;
    });
  }

  void _skip() {
    _timer?.cancel();
    setState(() => _isRunning = false);
    _advanceToNextMode(recordSession: false);
  }

  Future<void> _handleSessionCompleted() async {
    final settings = ref.read(settingsNotifierProvider);

    if (_currentMode == PomodoroMode.work) {
      // Record completed focus session in SQLite
      await ref.read(pomodoroRepositoryProvider).recordSession(
            durationMinutes: settings.workDuration,
            sessionType: 'work',
          );
      ref.invalidate(totalFocusMinutesProvider);
      ref.invalidate(todayFocusMinutesProvider);
    }

    await NotificationService.instance.showPomodoroFinished();
    _advanceToNextMode(recordSession: true);
  }

  void _advanceToNextMode({required bool recordSession}) {
    final settings = ref.read(settingsNotifierProvider);

    setState(() {
      if (_currentMode == PomodoroMode.work) {
        if (_currentCycle >= 4) {
          // Long break after 4th cycle
          _currentMode = PomodoroMode.longBreak;
          _totalDurationSeconds = settings.longBreakDuration * 60;
        } else {
          // Short break
          _currentMode = PomodoroMode.shortBreak;
          _totalDurationSeconds = settings.shortBreakDuration * 60;
        }
      } else {
        // Break finished -> Next work session
        if (_currentMode == PomodoroMode.longBreak) {
          _currentCycle = 1;
        } else {
          _currentCycle++;
        }
        _currentMode = PomodoroMode.work;
        _totalDurationSeconds = settings.workDuration * 60;
      }
      _remainingSeconds = _totalDurationSeconds;
    });
  }

  String get _timeDisplay {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  double get _progress {
    if (_totalDurationSeconds == 0) return 0.0;
    return (_totalDurationSeconds - _remainingSeconds) / _totalDurationSeconds;
  }

  Color _getModeColor(ThemeData theme) {
    switch (_currentMode) {
      case PomodoroMode.work:
        return const Color(0xFFE53935); // Crimson / Tomato
      case PomodoroMode.shortBreak:
        return const Color(0xFF43A047); // Green
      case PomodoroMode.longBreak:
        return const Color(0xFF1E88E5); // Blue
    }
  }

  String get _modeTitle {
    switch (_currentMode) {
      case PomodoroMode.work:
        return 'FOCUS TIME';
      case PomodoroMode.shortBreak:
        return 'SHORT BREAK';
      case PomodoroMode.longBreak:
        return 'LONG BREAK';
    }
  }

  String get _modeSubtitle {
    switch (_currentMode) {
      case PomodoroMode.work:
        return 'Stay focused on your task 🎯';
      case PomodoroMode.shortBreak:
        return 'Take a breather and stretch ☕';
      case PomodoroMode.longBreak:
        return 'Well done! Enjoy a full break 🌴';
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final modeColor = _getModeColor(theme);
    final todayMinutesAsync = ref.watch(todayFocusMinutesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('🍅 Pomodoro Focus'),
        centerTitle: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Mode Header Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: modeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: modeColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: modeColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _modeTitle,
                      style: TextStyle(
                        color: modeColor,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 4-Cycle Indicator Chips
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final cycleNumber = index + 1;
                  final isPast = cycleNumber < _currentCycle;
                  final isCurrent = cycleNumber == _currentCycle;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: isCurrent ? 28 : 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: isPast || (isCurrent && _currentMode == PomodoroMode.work)
                            ? modeColor
                            : theme.colorScheme.onSurface.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: isCurrent
                          ? Text(
                              '$cycleNumber',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text(
                'Cycle $_currentCycle of 4',
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 36),

              // Circular Countdown Timer
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 250,
                    height: 250,
                    child: CircularProgressIndicator(
                      value: _progress,
                      strokeWidth: 10,
                      strokeCap: StrokeCap.round,
                      backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(modeColor),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _timeDisplay,
                        style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _modeSubtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Control Buttons (Reset, Play/Pause, Skip)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Reset Button
                  IconButton.filledTonal(
                    iconSize: 26,
                    onPressed: _reset,
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Reset Cycle',
                  ),
                  const SizedBox(width: 24),
                  // Primary Play/Pause Button
                  FloatingActionButton.large(
                    backgroundColor: modeColor,
                    foregroundColor: Colors.white,
                    elevation: 6,
                    onPressed: _isRunning ? _pause : _start,
                    child: Icon(
                      _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 48,
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Skip Button
                  IconButton.filledTonal(
                    iconSize: 26,
                    onPressed: _skip,
                    icon: const Icon(Icons.skip_next_rounded),
                    tooltip: 'Skip to Next',
                  ),
                ],
              ),

              const SizedBox(height: 36),

              // Today's Focus Stats Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Today\'s Focus: ',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      todayMinutesAsync.maybeWhen(
                        data: (mins) => '$mins min',
                        orElse: () => '0 min',
                      ),
                      style: TextStyle(
                        color: modeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
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
