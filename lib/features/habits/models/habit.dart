import 'dart:convert';

const String defaultHabitEmoji = '\u{2B50}';

String normalizeHabitEmoji(String value) {
  if (value.isEmpty || value == '?') return defaultHabitEmoji;

  try {
    return utf8.decode(latin1.encode(value));
  } catch (_) {
    return value;
  }
}

class HabitDayRecord {
  final bool isCompleted;
  final String remarks;

  HabitDayRecord({this.isCompleted = false, this.remarks = ''});

  HabitDayRecord copyWith({
    bool? isCompleted,
    String? remarks,
  }) {
    return HabitDayRecord(
      isCompleted: isCompleted ?? this.isCompleted,
      remarks: remarks ?? this.remarks,
    );
  }

  factory HabitDayRecord.fromJson(Map<String, dynamic> json) {
    return HabitDayRecord(
      isCompleted: json['isCompleted'] ?? false,
      remarks: json['remarks'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'isCompleted': isCompleted,
        'remarks': remarks,
      };
}

class Habit {
  final String id;
  final String name;
  final String description;
  final int colorValue;
  final String iconEmoji;
  final DateTime createdAt;
  final int? reminderHour;
  final int? reminderMinute;
  final Map<String, HabitDayRecord> dailyRecords;

  Habit({
    required this.id,
    required this.name,
    this.description = '',
    this.colorValue = 0xFF008542,
    this.iconEmoji = defaultHabitEmoji,
    required this.createdAt,
    this.reminderHour,
    this.reminderMinute,
    Map<String, HabitDayRecord>? dailyRecords,
  }) : dailyRecords = dailyRecords ?? {};

  Habit copyWith({
    String? name,
    String? description,
    int? colorValue,
    String? iconEmoji,
    int? reminderHour,
    int? reminderMinute,
    bool clearReminder = false,
    Map<String, HabitDayRecord>? dailyRecords,
  }) {
    return Habit(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      colorValue: colorValue ?? this.colorValue,
      iconEmoji: iconEmoji ?? this.iconEmoji,
      createdAt: createdAt,
      reminderHour: clearReminder ? null : reminderHour ?? this.reminderHour,
      reminderMinute:
          clearReminder ? null : reminderMinute ?? this.reminderMinute,
      dailyRecords: dailyRecords ?? Map.from(this.dailyRecords),
    );
  }

  factory Habit.fromJson(Map<String, dynamic> json) {
    final rawRecords = json['dailyRecords'] as Map<String, dynamic>? ?? {};
    final records = rawRecords.map(
      (k, v) => MapEntry(k, HabitDayRecord.fromJson(v as Map<String, dynamic>)),
    );

    return Habit(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      colorValue: json['colorValue'] as int? ?? 0xFF008542,
      iconEmoji: normalizeHabitEmoji(
        json['iconEmoji'] as String? ?? defaultHabitEmoji,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      reminderHour: json['reminderHour'] as int?,
      reminderMinute: json['reminderMinute'] as int?,
      dailyRecords: records,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'colorValue': colorValue,
        'iconEmoji': iconEmoji,
        'createdAt': createdAt.toIso8601String(),
        'reminderHour': reminderHour,
        'reminderMinute': reminderMinute,
        'dailyRecords': dailyRecords.map((k, v) => MapEntry(k, v.toJson())),
      };
}
