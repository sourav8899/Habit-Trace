import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/notification_service.dart';
import '../../habits/models/habit.dart';
import '../../habits/widgets/habit_item.dart';
import '../../habits/logic/habit_provider.dart';
import '../../profile/screens/profile_screen.dart';
import 'stats_screen.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/theme/theme_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final bool openAddHabit;
  const HomeScreen({super.key, this.openAddHabit = false});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.openAddHabit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showAddHabitDialog();
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  int _calculateGlobalStreak(List<Habit> habits) {
    if (habits.isEmpty) return 0;
    int streak = 0;
    DateTime current = DateTime.now();

    bool todayDone = habits.any(
      (h) => h.dailyRecords[_formatDate(current)]?.isCompleted == true,
    );

    if (!todayDone) {
      DateTime yesterday = current.subtract(const Duration(days: 1));
      bool yesterdayDone = habits.any(
        (h) => h.dailyRecords[_formatDate(yesterday)]?.isCompleted == true,
      );
      if (!yesterdayDone) return 0;
      current = yesterday;
    }

    while (true) {
      bool done = habits.any(
        (h) => h.dailyRecords[_formatDate(current)]?.isCompleted == true,
      );
      if (done) {
        streak++;
        current = current.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  int _calculateEfficiency(List<Habit> habits) {
    if (habits.isEmpty) return 0;
    int total = 0;
    DateTime oneMonthAgo = DateTime.now().subtract(const Duration(days: 30));
    DateTime now = DateTime.now();
    for (final habit in habits) {
      for (var entry in habit.dailyRecords.entries) {
        if (entry.value.isCompleted) {
          try {
            final date = DateTime.parse(entry.key);
            if (date.isAfter(oneMonthAgo) &&
                date.isBefore(now.add(const Duration(days: 1)))) {
              total++;
            }
          } catch (_) {}
        }
      }
    }
    double efficiency = (total / (habits.length * 30)) * 100;
    return efficiency > 100 ? 100 : efficiency.round();
  }

  void _addHabit(
    String name,
    String description,
    int colorValue,
    String iconEmoji, {
    int? reminderHour,
    int? reminderMinute,
  }) {
    if (name.trim().isEmpty || description.trim().isEmpty) return;
    ref
        .read(habitProvider.notifier)
        .addHabit(
          name.trim(),
          description.trim(),
          colorValue,
          iconEmoji,
          reminderHour: reminderHour,
          reminderMinute: reminderMinute,
        );
  }

  Future<void> _removeHabit(Habit habit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Habit?'),
            content: Text(
              'Are you sure you want to delete "${habit.name}"? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      ref.read(habitProvider.notifier).removeHabit(habit.id);
      if (mounted) Navigator.pop(context);
    }
  }

  void _toggleToday(Habit habit) {
    final dateString = _formatDate(DateTime.now());
    final record = habit.dailyRecords[dateString] ?? HabitDayRecord();

    // Copy dictionary to avoid immutable violation
    final newRecords = Map<String, HabitDayRecord>.from(habit.dailyRecords);
    newRecords[dateString] = record.copyWith(isCompleted: !record.isCompleted);

    final updatedHabit = habit.copyWith(dailyRecords: newRecords);
    ref.read(habitProvider.notifier).updateHabit(updatedHabit);
  }

  void _openHabitStats(Habit habit) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StatsScreen(initialHabitId: habit.id)),
    );
  }

  void _showHabitDetails(Habit habit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Padding(
            padding: const EdgeInsets.only(top: 80.0),
            child: HabitItem(
              habit: habit,
              onEdit: () {
                Navigator.pop(context);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _showEditHabitDialog(habit);
                  }
                });
              },
              onDelete: () => _removeHabit(habit),
            ),
          ),
    );
  }

  String _formatReminderTime(TimeOfDay time) {
    final now = DateTime.now();
    final date = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(date));
  }

  void _showAddHabitDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descController = TextEditingController();

    int selectedColor = 0xFF008542;
    String selectedIcon = '⭐';
    bool reminderEnabled = false;
    TimeOfDay reminderTime = const TimeOfDay(hour: 20, minute: 0);
    bool showValidation = false;
    selectedIcon = defaultHabitEmoji;

    final List<int> colors = [
      0xFF008542, // Green
      0xFFEF4444, // Red
      0xFF3B82F6, // Blue
      0xFFF59E0B, // Amber
      0xFF8B5CF6, // Purple
      0xFFEC4899, // Pink
      0xFF06B6D4, // Cyan
      0xFFFF7849, // Orange
      0xFF10B981, // Emerald
      0xFF6366F1, // Indigo
    ];

    // 50 diverse emoji icons grouped by category
    final List<String> icons = [
      // Fitness & Health
      '🏋️', '🏃', '🚴', '🤺', '🧘', '🚼', '💧', '🥱', '💤', '🧬',
      // Learning & Productivity
      '📚', '📝', '💻', '🎓', '🔬', '📈', '💼', '✅', '🏆', '💬',
      // Food & Lifestyle
      '🥗', '☕', '🍎', '🍿', '🍺', '🚫', '💰', '🎨', '🎵', '🎧',
      // Nature & Mindfulness
      '🌱', '🌻', '🦋', '🌍', '✨', '🔥', '🌙', '☀️', '🧐', '💫',
      // Social & Fun
      '👊', '🤝', '💖', '🙏', '🎉', '🚀', '🎯', '🔑', '🐾', '👩‍💻',
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final nameMissing =
                showValidation && nameController.text.trim().isEmpty;
            final descriptionMissing =
                showValidation && descController.text.trim().isEmpty;

            return AlertDialog(
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              surfaceTintColor: Colors.transparent,
              title: Text(
                'Start a New Journey',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      cursorColor: Color(selectedColor),
                      decoration: InputDecoration(
                        hintText: "What's your new goal? ✍️",
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: nameMissing ? Colors.red : Colors.grey,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color:
                                nameMissing ? Colors.red : Color(selectedColor),
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.red,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descController,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      cursorColor: Color(selectedColor),
                      decoration: InputDecoration(
                        hintText: 'Why does this matter to you? ✨',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 13,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color:
                                descriptionMissing ? Colors.red : Colors.grey,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color:
                                descriptionMissing
                                    ? Colors.red
                                    : Color(selectedColor),
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.red,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        const Text(
                          'Want a daily Reminder?',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            letterSpacing: 1,
                          ),
                        ),
                        const Spacer(),
                        Switch(
                          value: reminderEnabled,
                          onChanged: (value) {
                            setState(() => reminderEnabled = value);
                          },
                        ),
                      ],
                    ),
                    if (reminderEnabled) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: reminderTime,
                          );
                          if (pickedTime != null) {
                            setState(() => reminderTime = pickedTime);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.notifications_active_outlined,
                                color: Color(selectedColor),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _formatReminderTime(reminderTime),
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const Icon(Icons.schedule, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    const Text(
                      'Pick your Vibe',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children:
                          colors.map((c) {
                            return GestureDetector(
                              onTap: () => setState(() => selectedColor = c),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Color(c),
                                  shape: BoxShape.circle,
                                  border:
                                      selectedColor == c
                                          ? Border.all(
                                            color: Colors.black87,
                                            width: 3,
                                          )
                                          : null,
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Icon',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          _safeHabitIcons.map((emoji) {
                            final isSelected = selectedIcon == emoji;
                            return GestureDetector(
                              onTap: () => setState(() => selectedIcon = emoji),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color:
                                      isSelected
                                          ? Color(
                                            selectedColor,
                                          ).withOpacity(0.15)
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color:
                                        isSelected
                                            ? Color(selectedColor)
                                            : Colors.grey.shade300,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    emoji,
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Color(selectedColor),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty ||
                        descController.text.trim().isEmpty) {
                      setState(() => showValidation = true);
                      return;
                    }

                    if (reminderEnabled) {
                      final permissionGranted =
                          await NotificationService.requestReminderPermissions();
                      if (!context.mounted) return;
                      if (!permissionGranted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Allow notifications and Alarms & reminders to enable exact habit reminders.',
                            ),
                          ),
                        );
                        return;
                      }
                    }

                    _addHabit(
                      nameController.text,
                      descController.text,
                      selectedColor,
                      selectedIcon,
                      reminderHour: reminderEnabled ? reminderTime.hour : null,
                      reminderMinute:
                          reminderEnabled ? reminderTime.minute : null,
                    );
                    Navigator.pop(context);
                  },
                  child: const Text("Let's Go!"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static const List<int> _habitColors = [
    0xFF008542,
    0xFFEF4444,
    0xFF3B82F6,
    0xFFF59E0B,
    0xFF8B5CF6,
    0xFFEC4899,
    0xFF06B6D4,
    0xFFFF7849,
    0xFF10B981,
    0xFF6366F1,
  ];

  static const List<String> _habitIcons = [
    'ðŸ‹ï¸',
    'ðŸƒ',
    'ðŸš´',
    'ðŸ¤º',
    'ðŸ§˜',
    'ðŸš¼',
    'ðŸ’§',
    'ðŸ¥±',
    'ðŸ’¤',
    'ðŸ§¬',
    'ðŸ“š',
    'ðŸ“',
    'ðŸ’»',
    'ðŸŽ“',
    'ðŸ”¬',
    'ðŸ“ˆ',
    'ðŸ’¼',
    'âœ…',
    'ðŸ†',
    'ðŸ’¬',
    'ðŸ¥—',
    'â˜•',
    'ðŸŽ',
    'ðŸ¿',
    'ðŸº',
    'ðŸš«',
    'ðŸ’°',
    'ðŸŽ¨',
    'ðŸŽµ',
    'ðŸŽ§',
    'ðŸŒ±',
    'ðŸŒ»',
    'ðŸ¦‹',
    'ðŸŒ',
    'âœ¨',
    'ðŸ”¥',
    'ðŸŒ™',
    'â˜€ï¸',
    'ðŸ§',
    'ðŸ’«',
    'ðŸ‘Š',
    'ðŸ¤',
    'ðŸ’–',
    'ðŸ™',
    'ðŸŽ‰',
    'ðŸš€',
    'ðŸŽ¯',
    'ðŸ”‘',
    'ðŸ¾',
    'ðŸ‘©â€ðŸ’»',
  ];

  static const List<String> _safeHabitIcons = [
    '\u{1F3CB}\u{FE0F}',
    '\u{1F3C3}',
    '\u{1F6B4}',
    '\u{1F93A}',
    '\u{1F9D8}',
    '\u{1F6BC}',
    '\u{1F4A7}',
    '\u{1F971}',
    '\u{1F4A4}',
    '\u{1F9EC}',
    '\u{1F4DA}',
    '\u{1F4DD}',
    '\u{1F4BB}',
    '\u{1F393}',
    '\u{1F52C}',
    '\u{1F4C8}',
    '\u{1F4BC}',
    '\u{2705}',
    '\u{1F3C6}',
    '\u{1F4AC}',
    '\u{1F957}',
    '\u{2615}',
    '\u{1F34E}',
    '\u{1F37F}',
    '\u{1F37A}',
    '\u{1F6AB}',
    '\u{1F4B0}',
    '\u{1F3A8}',
    '\u{1F3B5}',
    '\u{1F3A7}',
    '\u{1F331}',
    '\u{1F33B}',
    '\u{1F98B}',
    '\u{1F30D}',
    '\u{2728}',
    '\u{1F525}',
    '\u{1F319}',
    '\u{2600}\u{FE0F}',
    '\u{1F9D0}',
    '\u{1F4AB}',
    '\u{1F44A}',
    '\u{1F91D}',
    '\u{1F496}',
    '\u{1F64F}',
    '\u{1F389}',
    '\u{1F680}',
    '\u{1F3AF}',
    '\u{1F511}',
    '\u{1F43E}',
    '\u{1F469}\u{200D}\u{1F4BB}',
  ];

  void _showEditHabitDialog(Habit habit) {
    final nameController = TextEditingController(text: habit.name);
    final descController = TextEditingController(text: habit.description);
    int selectedColor = habit.colorValue;
    String selectedIcon = normalizeHabitEmoji(habit.iconEmoji);
    bool reminderEnabled =
        habit.reminderHour != null && habit.reminderMinute != null;
    TimeOfDay reminderTime = TimeOfDay(
      hour: habit.reminderHour ?? 20,
      minute: habit.reminderMinute ?? 0,
    );
    bool showValidation = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final nameMissing =
                showValidation && nameController.text.trim().isEmpty;
            final descriptionMissing =
                showValidation && descController.text.trim().isEmpty;

            return AlertDialog(
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              surfaceTintColor: Colors.transparent,
              title: Text(
                'Refine your Habit',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      cursorColor: Color(selectedColor),
                      decoration: InputDecoration(
                        labelText: 'Goal Name ✍️',
                        labelStyle: TextStyle(color: Colors.grey.shade500),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: nameMissing ? Colors.red : Colors.grey,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color:
                                nameMissing ? Colors.red : Color(selectedColor),
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.red,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descController,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      cursorColor: Color(selectedColor),
                      decoration: InputDecoration(
                        labelText: 'Motivation / Notes ✨',
                        labelStyle: TextStyle(color: Colors.grey.shade500),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color:
                                descriptionMissing ? Colors.red : Colors.grey,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color:
                                descriptionMissing
                                    ? Colors.red
                                    : Color(selectedColor),
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.red,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        const Text(
                          'Daily Reminder',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            letterSpacing: 1,
                          ),
                        ),
                        const Spacer(),
                        Switch(
                          value: reminderEnabled,
                          onChanged: (v) => setState(() => reminderEnabled = v),
                        ),
                      ],
                    ),
                    if (reminderEnabled) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: reminderTime,
                          );
                          if (picked != null) {
                            setState(() => reminderTime = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.notifications_active_outlined,
                                color: Color(selectedColor),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _formatReminderTime(reminderTime),
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const Icon(Icons.schedule, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    const Text(
                      'Change the Vibe',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children:
                          _habitColors.map((c) {
                            return GestureDetector(
                              onTap: () => setState(() => selectedColor = c),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Color(c),
                                  shape: BoxShape.circle,
                                  border:
                                      selectedColor == c
                                          ? Border.all(
                                            color: Colors.black87,
                                            width: 3,
                                          )
                                          : null,
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Switch Icon',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          _safeHabitIcons.map((emoji) {
                            final isSelected = selectedIcon == emoji;
                            return GestureDetector(
                              onTap: () => setState(() => selectedIcon = emoji),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color:
                                      isSelected
                                          ? Color(
                                            selectedColor,
                                          ).withOpacity(0.15)
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color:
                                        isSelected
                                            ? Color(selectedColor)
                                            : Colors.grey.shade300,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    emoji,
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Color(selectedColor),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty ||
                        descController.text.trim().isEmpty) {
                      setState(() => showValidation = true);
                      return;
                    }
                    if (reminderEnabled) {
                      final permissionGranted =
                          await NotificationService.requestReminderPermissions();
                      if (!context.mounted) return;
                      if (!permissionGranted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Allow notifications and Alarms & reminders to enable exact habit reminders.',
                            ),
                          ),
                        );
                        return;
                      }
                    }

                    ref
                        .read(habitProvider.notifier)
                        .updateHabit(
                          habit.copyWith(
                            name: nameController.text.trim(),
                            description: descController.text.trim(),
                            colorValue: selectedColor,
                            iconEmoji: selectedIcon,
                            reminderHour:
                                reminderEnabled ? reminderTime.hour : null,
                            reminderMinute:
                                reminderEnabled ? reminderTime.minute : null,
                            clearReminder: !reminderEnabled,
                          ),
                        );
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMiniStreak(Habit habit) {
    final today = DateTime.now();
    List<Widget> boxes = [];

    for (int i = 4; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final dateString = _formatDate(date);
      final isCompleted = habit.dailyRecords[dateString]?.isCompleted ?? false;

      boxes.add(
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            color:
                isCompleted
                    ? Color(habit.colorValue)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
    }
    return Row(children: boxes);
  }

  Widget _buildHabitCard(Habit habit) {
    final todayStr = _formatDate(DateTime.now());
    final isCompletedToday = habit.dailyRecords[todayStr]?.isCompleted ?? false;
    final Color habitColor = Color(habit.colorValue);
    final String iconEmoji = habit.iconEmoji;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.06),
            blurRadius: 40,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Toggle Button Section
          GestureDetector(
            onTap: () => _toggleToday(habit),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isCompletedToday ? habitColor : Colors.transparent,
                  border: Border.all(
                    color: isCompletedToday ? habitColor : Colors.grey.shade300,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    isCompletedToday
                        ? const Icon(Icons.check, size: 22, color: Colors.white)
                        : null,
              ),
            ),
          ),
          // Habit Info Section (Clickable for Details)
          Expanded(
            child: GestureDetector(
              onTap: () => _showHabitDetails(habit),
              onLongPress: () => _openHabitStats(habit),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 18, 18, 18),
                child: Row(
                  children: [
                    Text(iconEmoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        habit.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color:
                              isCompletedToday
                                  ? Colors.grey.shade400
                                  : Theme.of(context).colorScheme.onSurface,
                          decoration:
                              isCompletedToday
                                  ? TextDecoration.lineThrough
                                  : null,
                        ),
                      ),
                    ),
                    _buildMiniStreak(habit),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(int globalStreak, int efficiency) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: cs.onSurface.withValues(alpha: 0.06),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EFFICIENCY',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$efficiency%',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: cs.outlineVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STREAK',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$globalStreak',
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      'd',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(List<Habit> activeHabits) {
    final int globalStreak = _calculateGlobalStreak(activeHabits);
    final int efficiency = _calculateEfficiency(activeHabits);

    final months = [
      'JANUARY',
      'FEBRUARY',
      'MARCH',
      'APRIL',
      'MAY',
      'JUNE',
      'JULY',
      'AUGUST',
      'SEPTEMBER',
      'OCTOBER',
      'NOVEMBER',
      'DECEMBER',
    ];
    final dateString =
        '${months[DateTime.now().month - 1]} ${DateTime.now().year}';

    final userState = ref.watch(userProvider);
    final themeMode = ref.watch(themeProvider);

    String getGreeting() {
      var hour = DateTime.now().hour;
      final name = userState.name;
      if (hour < 12) return 'Good Morning, $name.';
      if (hour < 17) return 'Good Afternoon, $name.';
      return 'Good Evening, $name.';
    }

    String streakMessage =
        globalStreak > 0
            ? 'Keep your $globalStreak-day streak alive today.'
            : 'Start building a new run today.';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              },
              child: Container(
                child: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.5),
                  radius: 16,
                  child: Icon(
                    Icons.person,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'HabitTrace',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              ref.read(themeProvider.notifier).toggleTheme();
            },
            icon: Icon(
              themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateString,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      getGreeting(),
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.onSurface,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      streakMessage,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Daily Rituals',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        fontSize: 16,
                      ),
                    ),
                    GestureDetector(
                      onTap: _showAddHabitDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'New Habit',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (activeHabits.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      'No habits yet...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              ...activeHabits.map((habit) => _buildHabitCard(habit)),

              const SizedBox(height: 24),

              _buildStatsCard(globalStreak, efficiency),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch riverpod state directly and build
    final activeHabitsList = ref.watch(habitProvider);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex > 1 ? 0 : _currentIndex,
        children: [_buildDashboard(activeHabitsList), StatsScreen()],
      ),
      bottomNavigationBar: BottomNavigationBar(
        elevation: 10,
        currentIndex: _currentIndex > 1 ? 0 : _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Icon(Icons.grid_view_rounded),
            ),
            label: 'DASHBOARD',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Icon(Icons.bar_chart_rounded),
            ),
            label: 'STATS',
          ),
        ],
      ),
    );
  }
}
