import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/notification_service.dart';
import '../../../settings/providers/settings_provider.dart';

class PomodoroPage extends ConsumerStatefulWidget {
  const PomodoroPage({super.key});

  @override
  ConsumerState<PomodoroPage> createState() => _PomodoroPageState();
}

class _PomodoroPageState extends ConsumerState<PomodoroPage> {

  Timer? timer;

  late int remainingSeconds;

  bool running = false;
  bool isBreak = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final settings = ref.read(settingsNotifierProvider);
      remainingSeconds = settings.workDuration * 60;
      _initialized = true;
    }
  }

  void start() {
    if (running) return;

    setState(() {
      running = true;
    });

    timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (remainingSeconds > 0) {
          setState(() {
            remainingSeconds--;
          });
        } else {
          timer?.cancel();

          setState(() {
            running = false;
          });

          NotificationService.instance.showPomodoroFinished();

          switchSession();
        }
      },
    );
  }

  void pause() {
    timer?.cancel();

    setState(() {
      running = false;
    });
  }

  void reset() {
    timer?.cancel();

    final settings = ref.read(settingsNotifierProvider);

    setState(() {
      running = false;
      remainingSeconds = isBreak ? settings.shortBreakDuration * 60 : settings.workDuration * 60;
    });
  }

  void switchSession() {
    final settings = ref.read(settingsNotifierProvider);
    setState(() {
      isBreak = !isBreak;
      remainingSeconds = isBreak ? settings.shortBreakDuration * 60 : settings.workDuration * 60;
    });
  }

  String get time {
    final minutes = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🍅 Pomodoro'),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isBreak ? 'BREAK' : 'FOCUS',
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 80,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 40,
                    onPressed: reset,
                    icon: const Icon(
                      Icons.refresh,
                    ),
                  ),
                  const SizedBox(width: 20),
                  FloatingActionButton.large(
                    onPressed: running ? pause : start,
                    child: Icon(
                      running ? Icons.pause : Icons.play_arrow,
                      size: 40,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Text(
                isBreak ? 'Take a short break ☕' : 'Focus on your task 🎯',
                style: const TextStyle(
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
