import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';
import '../../../core/services/notification_service.dart';
import '../models/habit.dart';
import '../repositories/habit_repository.dart';
import '../../../core/services/widget_service.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize sharedPreferencesProvider in main.dart');
});

final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocalHabitRepository(prefs);
});

class HabitNotifier extends Notifier<List<Habit>> {
  @override
  List<Habit> build() {
    Future.microtask(_loadAll);
    return [];
  }

  HabitRepository get _repo => ref.read(habitRepositoryProvider);

  /// Synchronizes state with widget data (used on app resume)
  Future<void> syncWithWidget() async {
    await _loadAll();
  }

  Future<void> _loadAll() async {
    List<Habit> loadedState = await _repo.getHabits();

    try {
      final widgetDataStr =
          await HomeWidget.getWidgetData<String>('habits_list');
      if (widgetDataStr != null && widgetDataStr.isNotEmpty) {
        final List<dynamic> widgetData =
            jsonDecode(widgetDataStr) as List<dynamic>;
        final Map<String, Map<String, bool>> widgetCompletions = {};
        for (final data in widgetData) {
          if (data is Map<String, dynamic> &&
              data['id'] != null &&
              data['completions'] is Map) {
            widgetCompletions[data['id'] as String] =
                (data['completions'] as Map).map(
              (k, v) => MapEntry(k as String, v as bool),
            );
          }
        }

        bool stateChanged = false;
        final List<Habit> mergedState = [];
        for (final habit in loadedState) {
          final wCompletions = widgetCompletions[habit.id];
          if (wCompletions != null) {
            final newRecords =
                Map<String, HabitDayRecord>.from(habit.dailyRecords);
            bool habitChanged = false;
            for (final entry in wCompletions.entries) {
              final currentRecord =
                  newRecords[entry.key] ?? HabitDayRecord();
              if (currentRecord.isCompleted != entry.value) {
                newRecords[entry.key] =
                    currentRecord.copyWith(isCompleted: entry.value);
                habitChanged = true;
                stateChanged = true;
              }
            }
            if (habitChanged) {
              mergedState.add(habit.copyWith(dailyRecords: newRecords));
              continue;
            }
          }
          mergedState.add(habit);
        }
        loadedState = mergedState;

        if (stateChanged) {
          await _repo.saveHabits(loadedState);
        }
      }
    } catch (e) {
      debugPrint('[HabitProvider] Widget sync error: $e');
    }

    state = loadedState;
    WidgetService.update(state);
    await NotificationService.syncHabitReminders(state);
  }

  Future<void> addHabit(
    String name,
    String description,
    int colorValue,
    String iconEmoji, {
    int? reminderHour,
    int? reminderMinute,
  }) async {
    final habit = Habit(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      description: description,
      colorValue: colorValue,
      iconEmoji: iconEmoji,
      createdAt: DateTime.now(),
      reminderHour: reminderHour,
      reminderMinute: reminderMinute,
    );
    final newState = [...state, habit];
    state = newState;
    await _repo.saveHabits(newState);
    WidgetService.update(newState);
    await NotificationService.syncHabitReminders(newState);
  }

  Future<void> removeHabit(String id) async {
    final newState = state.where((h) => h.id != id).toList();
    state = newState;
    await _repo.saveHabits(newState);
    WidgetService.update(newState);
    await NotificationService.syncHabitReminders(newState);
  }

  Future<void> clearAll() async {
    state = [];
    await _repo.saveHabits([]);
    WidgetService.update([]);
    await NotificationService.syncHabitReminders([]);
  }

  Future<void> updateHabit(Habit habit) async {
    final newState = [
      for (final h in state)
        if (h.id == habit.id) habit else h
    ];
    state = newState;
    await _repo.saveHabits(newState);
    WidgetService.update(newState);
    await NotificationService.syncHabitReminders(newState);
  }
}

final habitProvider = NotifierProvider<HabitNotifier, List<Habit>>(() {
  return HabitNotifier();
});
