import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../../features/habits/models/habit.dart';

/// Syncs habit state to the Android/iOS home screen widget.
/// Call [WidgetService.update] whenever habit data changes.
class WidgetService {
  static const _appGroupId = 'com.yourname.habit_flow';
  static const _qualifiedWidgetName =
      'com.yourname.habit_flow.HabitWidget'; // Android

  /// Call once at app startup
  static Future<void> init() async {
    try {
      await HomeWidget.setAppGroupId(_appGroupId);
    } catch (e) {
      debugPrint('[WidgetService] init error: $e');
    }
  }

  /// Push full individual habit data to the widget
  static Future<void> update(List<Habit> habits) async {
    try {
      final habitsData = habits.map((h) {
        final completions = <String, bool>{};
        for (final entry in h.dailyRecords.entries) {
          if (entry.value.isCompleted) completions[entry.key] = true;
        }
        return {
          'id': h.id,
          'name': h.name,
          'description': h.description,
          'colorValue': h.colorValue,
          'iconEmoji': h.iconEmoji,
          'createdAt': h.createdAt.toIso8601String(),
          'completions': completions,
        };
      }).toList();

      await HomeWidget.saveWidgetData<String>(
        'habits_list',
        jsonEncode(habitsData),
      );

      await HomeWidget.updateWidget(
        qualifiedAndroidName: _qualifiedWidgetName,
      );
    } catch (e) {
      debugPrint('[WidgetService] update error: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────

}
