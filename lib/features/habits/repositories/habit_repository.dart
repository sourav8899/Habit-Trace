import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/habit.dart';

abstract class HabitRepository {
  Future<List<Habit>> getHabits();
  Future<void> saveHabits(List<Habit> habits);
}

class LocalHabitRepository implements HabitRepository {
  static const _key = 'habits_data';
  final SharedPreferences _prefs;

  LocalHabitRepository(this._prefs);

  @override
  Future<List<Habit>> getHabits() async {
    final str = _prefs.getString(_key);
    if (str == null) return [];
    
    try {
      final List<dynamic> jsonList = jsonDecode(str);
      return jsonList.map((e) => Habit.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      return []; // Return empty on parsing error instead of crashing
    }
  }

  @override
  Future<void> saveHabits(List<Habit> habits) async {
    final str = jsonEncode(habits.map((e) => e.toJson()).toList());
    await _prefs.setString(_key, str);
  }
}
