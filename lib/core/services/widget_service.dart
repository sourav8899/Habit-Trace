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

  static const _qualifiedWidgetNameSmall =
      'com.yourname.habit_flow.HabitWidgetSmall'; // Android 2x2 widget

  /// Call once at app startup
  static Future<void> init() async {
    try {
      await HomeWidget.setAppGroupId(_appGroupId);
    } catch (e) {
      debugPrint('[WidgetService] init error: $e');
    }
  }

  /// Push full individual habit data to the widget.
  /// Merges existing widget-side completions with Flutter state so that
  /// a widget tick is never overwritten by the next [update] call.
  static Future<void> update(List<Habit> habits) async {
    try {
      // Read the existing widget data so we can merge completions
      final existingJson =
          await HomeWidget.getWidgetData<String>('habits_list');
      Map<String, Map<String, bool>> existingCompletions = {};
      if (existingJson != null && existingJson.isNotEmpty) {
        try {
          final List<dynamic> existing =
              jsonDecode(existingJson) as List<dynamic>;
          for (final item in existing) {
            if (item is Map<String, dynamic> &&
                item['id'] is String &&
                item['completions'] is Map) {
              final raw = item['completions'] as Map;
              existingCompletions[item['id'] as String] = {
                for (final e in raw.entries)
                  if (e.value is bool) e.key.toString(): e.value as bool,
              };
            }
          }
        } catch (_) {}
      }

      final habitsData = habits.map((h) {
        // Start from the widget's existing completions for this habit
        final merged = Map<String, bool>.from(
          existingCompletions[h.id] ?? {},
        );
        // Apply the Flutter-side records on top (Flutter is authoritative)
        for (final entry in h.dailyRecords.entries) {
          merged[entry.key] = entry.value.isCompleted;
        }
        // Only keep true values to keep the payload small
        merged.removeWhere((_, v) => !v);
        return {
          'id': h.id,
          'name': h.name,
          'description': h.description,
          'colorValue': h.colorValue,
          'iconEmoji': h.iconEmoji,
          'createdAt': h.createdAt.toIso8601String(),
          'completions': merged,
        };
      }).toList();

      await HomeWidget.saveWidgetData<String>(
        'habits_list',
        jsonEncode(habitsData),
      );

      await HomeWidget.updateWidget(
        qualifiedAndroidName: _qualifiedWidgetName,
      );
      await HomeWidget.updateWidget(
        qualifiedAndroidName: _qualifiedWidgetNameSmall,
      );
    } catch (e) {
      debugPrint('[WidgetService] update error: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────

}
