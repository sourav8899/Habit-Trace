import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  Future<void> _loadAll() async {
    state = await _repo.getHabits();
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
