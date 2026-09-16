import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/sqlite_database.dart';

class PomodoroSession {
  final String id;
  final int durationMinutes;
  final DateTime completedAt;
  final String sessionType; // 'work', 'short_break', 'long_break'

  PomodoroSession({
    required this.id,
    required this.durationMinutes,
    required this.completedAt,
    required this.sessionType,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'duration_minutes': durationMinutes,
      'completed_at': completedAt.toIso8601String(),
      'session_type': sessionType,
    };
  }

  factory PomodoroSession.fromMap(Map<String, dynamic> map) {
    return PomodoroSession(
      id: map['id'] as String,
      durationMinutes: map['duration_minutes'] as int,
      completedAt: DateTime.parse(map['completed_at'] as String),
      sessionType: map['session_type'] as String,
    );
  }
}

class PomodoroRepository {
  final SqliteDatabase _databaseHelper;

  PomodoroRepository({SqliteDatabase? databaseHelper})
      : _databaseHelper = databaseHelper ?? SqliteDatabase.instance;

  Future<void> recordSession({
    required int durationMinutes,
    required String sessionType,
  }) async {
    try {
      final db = await _databaseHelper.database;
      final session = PomodoroSession(
        id: const Uuid().v4(),
        durationMinutes: durationMinutes,
        completedAt: DateTime.now(),
        sessionType: sessionType,
      );
      await db.insert('pomodoro_sessions', session.toMap());
    } catch (e) {
      debugPrint('Error recording pomodoro session: $e');
    }
  }

  Future<int> getTotalFocusMinutes() async {
    try {
      final db = await _databaseHelper.database;
      final result = await db.rawQuery(
        "SELECT SUM(duration_minutes) as total FROM pomodoro_sessions WHERE session_type = 'work'",
      );
      final total = result.first['total'];
      return total != null ? (total as num).toInt() : 0;
    } catch (e) {
      debugPrint('Error calculating total focus minutes: $e');
      return 0;
    }
  }

  Future<int> getTodayFocusMinutes() async {
    try {
      final db = await _databaseHelper.database;
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final result = await db.rawQuery(
        "SELECT SUM(duration_minutes) as total FROM pomodoro_sessions WHERE session_type = 'work' AND completed_at LIKE '$todayStr%'",
      );
      final total = result.first['total'];
      return total != null ? (total as num).toInt() : 0;
    } catch (e) {
      return 0;
    }
  }

  Future<int> getCompletedSessionsCount() async {
    try {
      final db = await _databaseHelper.database;
      final result = await db.rawQuery(
        "SELECT COUNT(*) as cnt FROM pomodoro_sessions WHERE session_type = 'work'",
      );
      return (result.first['cnt'] as num?)?.toInt() ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<List<PomodoroSession>> getRecentSessions({int limit = 10}) async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        'pomodoro_sessions',
        orderBy: 'completed_at DESC',
        limit: limit,
      );
      return maps.map((m) => PomodoroSession.fromMap(m)).toList();
    } catch (e) {
      return [];
    }
  }
}

final pomodoroRepositoryProvider = Provider<PomodoroRepository>((ref) {
  return PomodoroRepository();
});

final totalFocusMinutesProvider = FutureProvider<int>((ref) async {
  return ref.watch(pomodoroRepositoryProvider).getTotalFocusMinutes();
});

final todayFocusMinutesProvider = FutureProvider<int>((ref) async {
  return ref.watch(pomodoroRepositoryProvider).getTodayFocusMinutes();
});
