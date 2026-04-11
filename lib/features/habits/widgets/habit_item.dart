import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/notification_service.dart';
import '../models/habit.dart';
import '../logic/habit_provider.dart';

class HabitItem extends ConsumerStatefulWidget {
  final Habit habit;
  final VoidCallback onDelete;

  const HabitItem({super.key, required this.habit, required this.onDelete});

  @override
  ConsumerState<HabitItem> createState() => _HabitItemState();
}

class _HabitItemState extends ConsumerState<HabitItem> {
  // Read latest habit state without subscribing to changes (for callbacks)
  Habit get _currentHabitRead {
    final habits = ref.read(habitProvider);
    return habits.firstWhere(
      (h) => h.id == widget.habit.id,
      orElse: () => widget.habit,
    );
  }

  void _updateHabitRecord(String dateString, HabitDayRecord newRecord) {
    final currentHabit = _currentHabitRead;
    final newRecords = Map<String, HabitDayRecord>.from(
      currentHabit.dailyRecords,
    );
    newRecords[dateString] = newRecord;
    final updatedHabit = currentHabit.copyWith(dailyRecords: newRecords);

    ref.read(habitProvider.notifier).updateHabit(updatedHabit);
  }

  void _toggleDate(DateTime date) {
    final currentHabit = _currentHabitRead;
    final dateString = _formatDate(date);
    final record = currentHabit.dailyRecords[dateString] ?? HabitDayRecord();
    _updateHabitRecord(
      dateString,
      record.copyWith(isCompleted: !record.isCompleted),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatMonthShort(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[date.month - 1];
  }

  String _formatReadableDate(DateTime date) {
    return '${_formatMonthShort(date)} ${date.day}, ${date.year}';
  }

  String _formatReminderLabel(Habit habit) {
    if (habit.reminderHour == null || habit.reminderMinute == null) {
      return 'Reminder off';
    }

    final time = TimeOfDay(
      hour: habit.reminderHour!,
      minute: habit.reminderMinute!,
    );

    return MaterialLocalizations.of(context).formatTimeOfDay(time);
  }

  Future<void> _setReminder(Habit habit) async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: habit.reminderHour ?? 20,
        minute: habit.reminderMinute ?? 0,
      ),
    );

    if (pickedTime == null || !mounted) return;

    final permissionGranted =
        await NotificationService.requestReminderPermissions();
    if (!mounted) return;

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

    ref.read(habitProvider.notifier).updateHabit(
      habit.copyWith(
        reminderHour: pickedTime.hour,
        reminderMinute: pickedTime.minute,
      ),
    );
  }

  void _clearReminder(Habit habit) {
    ref.read(habitProvider.notifier).updateHabit(
      habit.copyWith(clearReminder: true),
    );
  }

  void _showDayDetails(DateTime date) {
    final currentHabit = _currentHabitRead;
    final dateString = _formatDate(date);
    final record = currentHabit.dailyRecords[dateString] ?? HabitDayRecord();
    final textController = TextEditingController(text: record.remarks);

    showDialog(
      context: context,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surfaceContainerHighest,
          surfaceTintColor: Colors.transparent,
          title: Text(
            _formatReadableDate(date),
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Status: ',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 16),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          record.isCompleted
                              ? cs.primaryContainer.withValues(alpha: 0.5)
                              : Colors.redAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      record.isCompleted ? 'Completed' : 'Not Completed',
                      style: TextStyle(
                        color:
                            record.isCompleted
                                ? cs.primary
                                : Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: textController,
                style: TextStyle(color: cs.onSurface),
                cursorColor: cs.primary,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Remarks / Notes',
                  labelStyle: TextStyle(color: cs.onSurfaceVariant),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: cs.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: cs.primary),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: cs.onSurfaceVariant)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                _updateHabitRecord(
                  dateString,
                  record.copyWith(remarks: textController.text.trim()),
                );
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch latest state updates to trigger widget rebuilds instantly
    final habitsList = ref.watch(habitProvider);
    final currentHabit = habitsList.firstWhere(
      (h) => h.id == widget.habit.id,
      orElse: () => widget.habit,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  currentHabit.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.grey,
                  size: 24,
                ),
                onPressed: widget.onDelete,
                splashRadius: 24,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_active_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily reminder',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatReminderLabel(currentHabit),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _setReminder(currentHabit),
                  child: Text(
                    currentHabit.reminderHour == null ||
                            currentHabit.reminderMinute == null
                        ? 'Set'
                        : 'Change',
                  ),
                ),
                if (currentHabit.reminderHour != null &&
                    currentHabit.reminderMinute != null)
                  IconButton(
                    onPressed: () => _clearReminder(currentHabit),
                    icon: const Icon(Icons.notifications_off_outlined),
                    tooltip: 'Turn off reminder',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: false, // Start at current date (beginning of window)
            physics: const BouncingScrollPhysics(),
            child: _buildGitHubGraph(currentHabit),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildGitHubGraph(Habit currentHabit) {
    final today = DateTime.now();
    final todayUtc = DateTime.utc(today.year, today.month, today.day);
    final createdUtc = DateTime.utc(currentHabit.createdAt.year, currentHabit.createdAt.month, currentHabit.createdAt.day);
    
    int diffDays = todayUtc.difference(createdUtc).inDays;
    if (diffDays < 0) diffDays = 0;
    
    const int totalDays = 15 * 7;
    final int currentWindow = diffDays ~/ totalDays;
    
    final baseDate = createdUtc.add(Duration(days: currentWindow * totalDays));

    const double squareSize = 26.0;
    const double marginSize = 4.0;

    List<DateTime> dates = [];
    for (int i = 0; i < totalDays; i++) {
      final d = baseDate.add(Duration(days: i));
      dates.add(DateTime(d.year, d.month, d.day)); // Local time for UI
    }

    List<Widget> columns = [];
    List<Widget> currentColumnSquares = [];
    String? monthForColumn;
    int lastMonth = dates.first.month;

    final Color habitColor = Color(currentHabit.colorValue);

    for (int i = 0; i < dates.length; i++) {
      final date = dates[i];
      final monthStr = _formatMonthShort(date);

      if (i == 0) monthForColumn = monthStr;

      if (date.month != lastMonth) {
        while (currentColumnSquares.length < 7) {
          currentColumnSquares.add(
            const SizedBox(height: squareSize + marginSize),
          );
        }

        columns.add(
          _buildColumnWidget(currentColumnSquares, monthForColumn, marginSize),
        );

        currentColumnSquares = [];
        monthForColumn = monthStr;
        lastMonth = date.month;
      }

      final dateString = _formatDate(date);
      final record = currentHabit.dailyRecords[dateString] ?? HabitDayRecord();
      final isCompleted = record.isCompleted;
      final hasRemarks = record.remarks.isNotEmpty;

      final baseColor = isCompleted ? habitColor : Theme.of(context).colorScheme.surfaceContainerHighest;
      // final isFirstOfMonth = date.day == 1;

      currentColumnSquares.add(
        GestureDetector(
          onTap: () => _toggleDate(date),
          onLongPress: () => _showDayDetails(date),
          child: Container(
            width: squareSize,
            height: squareSize,
            margin: const EdgeInsets.only(bottom: marginSize),
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color:
                    isCompleted
                        ? Colors.transparent
                        : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? Colors.white : Colors.black54,
                  ),
                ),
                if (hasRemarks)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color:
                            isCompleted ? Colors.white54 : Colors.grey.shade500,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );

      if (currentColumnSquares.length == 7) {
        columns.add(
          _buildColumnWidget(currentColumnSquares, monthForColumn, marginSize),
        );
        currentColumnSquares = [];
        monthForColumn = null;
      }
    }

    if (currentColumnSquares.isNotEmpty) {
      while (currentColumnSquares.length < 7) {
        currentColumnSquares.add(
          const SizedBox(height: squareSize + marginSize),
        );
      }
      columns.add(
        _buildColumnWidget(currentColumnSquares, monthForColumn, marginSize),
      );
    }

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: columns);
  }

  Widget _buildColumnWidget(
    List<Widget> squares,
    String? monthLabel,
    double marginSize,
  ) {
    return Padding(
      padding: EdgeInsets.only(right: marginSize),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 16,
            child:
                monthLabel != null
                    ? Text(
                      monthLabel,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                    : null,
          ),
          const SizedBox(height: 4),
          ...squares,
        ],
      ),
    );
  }
}
