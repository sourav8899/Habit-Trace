import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../../habits/models/habit.dart';
import '../../habits/logic/habit_provider.dart';
import '../../../core/services/notification_service.dart';
import '../../profile/screens/profile_screen.dart';

class StatsScreen extends ConsumerStatefulWidget {
  final String? initialHabitId;
  StatsScreen({super.key, this.initialHabitId});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  int _selectedYear = DateTime.now().year;
  late String _selectedViewMode;

  @override
  void initState() {
    super.initState();
    _selectedViewMode = widget.initialHabitId ?? 'Overview';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _toggleToday(Habit habit) {
    final dateString = _formatDate(DateTime.now());
    final record = habit.dailyRecords[dateString] ?? HabitDayRecord();

    final newRecords = Map<String, HabitDayRecord>.from(habit.dailyRecords);
    newRecords[dateString] = record.copyWith(isCompleted: !record.isCompleted);

    final updatedHabit = habit.copyWith(dailyRecords: newRecords);
    ref.read(habitProvider.notifier).updateHabit(updatedHabit);
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

  int _calculateTotalCompleted(List<Habit> habits) {
    int total = 0;
    for (final habit in habits) {
      for (final record in habit.dailyRecords.values) {
        if (record.isCompleted) total++;
      }
    }
    return total;
  }

  int _calculateLastMonthCompleted(List<Habit> habits) {
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
    return total;
  }

  List<int> _get12MonthCompletionsForYear(List<Habit> habits, int year) {
    List<int> completions = List.filled(12, 0);

    for (final habit in habits) {
      for (var entry in habit.dailyRecords.entries) {
        if (entry.value.isCompleted) {
          try {
            final date = DateTime.parse(entry.key);
            if (date.year == year) {
              completions[date.month - 1]++;
            }
          } catch (_) {}
        }
      }
    }
    return completions;
  }

  String _getMonthLabelAbsolute(int monthIndex) {
    final months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return months[monthIndex];
  }

  String _getMonthLabel(int monthsAgo) {
    DateTime date = DateTime.now().subtract(Duration(days: 30 * monthsAgo));
    final months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return months[date.month - 1];
  }

  String curr = "overview";
  @override
  Widget build(BuildContext context) {
    final allHabits = ref.watch(habitProvider);
    final hasNoHabits = allHabits.isEmpty;

    if (_selectedViewMode != 'Overview' &&
        !allHabits.any((h) => h.id == _selectedViewMode)) {
      _selectedViewMode = 'Overview';
    }

    final habitsToAnalyze =
        _selectedViewMode == 'Overview'
            ? allHabits
            : allHabits.where((h) => h.id == _selectedViewMode).toList();

    final globalStreak = _calculateGlobalStreak(habitsToAnalyze);
    final totalCompleted = _calculateTotalCompleted(habitsToAnalyze);
    final lastMonthCompleted = _calculateLastMonthCompleted(habitsToAnalyze);

    final selectedHabit =
        _selectedViewMode == 'Overview'
            ? null
            : allHabits.firstWhere((h) => h.id == _selectedViewMode);

    final title =
        selectedHabit != null ? selectedHabit.name : 'Your Mastery Journey';
    final subtitle =
        selectedHabit != null && selectedHabit.description.isNotEmpty
            ? selectedHabit.description
            : (selectedHabit != null
                ? 'No description yet! Add one to stay inspired. ✨'
                : 'Tracking your progress across all habits. You are doing amazing work! 🚀');
    final tag = selectedHabit != null ? 'HABIT DETAILS' : 'GLOBAL OVERVIEW';

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
          if (selectedHabit != null) ...[
            IconButton(
              icon: Icon(
                Icons.edit_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              onPressed: () => _showEditHabitDialog(selectedHabit),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.grey),
              onPressed: () => _removeHabit(selectedHabit),
            ),
          ],
        ],
      ),
      body:
          hasNoHabits
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bar_chart_rounded,
                        size: 56,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Please add a habit',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your stats will appear here once you create your first habit.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
              : ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.show_chart,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'VIEW MODE',
                                style: TextStyle(
                                  fontSize: 10,
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                              DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedViewMode,
                                  isDense: true,
                                  isExpanded: true,
                                  dropdownColor:
                                      Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                  icon: Icon(
                                    Icons.keyboard_arrow_down,
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                    size: 20,
                                  ),
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedViewMode = val);
                                    }
                                  },
                                  items: [
                                    const DropdownMenuItem(
                                      value: 'Overview',
                                      child: Text('Overview (All Habits)'),
                                    ),
                                    ...allHabits.map(
                                      (h) => DropdownMenuItem(
                                        value: h.id,
                                        child: Text(
                                          h.name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    tag,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onSurface,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Habit Info Card (only when viewing a single habit) ──
                  if (selectedHabit != null) _buildHabitInfoCard(selectedHabit),
                  if (selectedHabit != null) const SizedBox(height: 24),

                  if (habitsToAnalyze.isNotEmpty)
                    _buildHeatmapCard(habitsToAnalyze),
                  if (habitsToAnalyze.isNotEmpty) const SizedBox(height: 24),

                  _buildStreakCard(globalStreak),
                  const SizedBox(height: 24),

                  _buildCompletedCard(totalCompleted, lastMonthCompleted),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'RANK',
                                style: TextStyle(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                totalCompleted > 50 ? 'Master' : 'Novice',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'LEVEL',
                                style: TextStyle(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${(totalCompleted / 10).floor() + 1}',
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // _buildBarChartCard(habitsToAnalyze),
                  const SizedBox(height: 24),

                  Text(
                    'Achievements',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildAchievementsGrid(globalStreak, totalCompleted),
                  const SizedBox(height: 32),
                ],
              ),
    );
  }

  Widget _buildBarChartCard(List<Habit> habits) {
    List<int> monthlyCounts = _get12MonthCompletionsForYear(
      habits,
      _selectedYear,
    );
    int maxCount = monthlyCounts.fold(0, math.max);
    if (maxCount == 0) maxCount = 1;

    List<int> availableYears = [_selectedYear];
    for (final h in habits) {
      for (var k in h.dailyRecords.keys) {
        try {
          availableYears.add(DateTime.parse(k).year);
        } catch (_) {}
      }
    }
    availableYears =
        availableYears.toSet().toList()..sort((a, b) => b.compareTo(a));

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.06),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Consistency Growth',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 0,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton<int>(
                  value: _selectedYear,
                  underline: const SizedBox(),
                  dropdownColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  icon: Icon(
                    Icons.arrow_drop_down,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedYear = val);
                  },
                  items:
                      availableYears
                          .map(
                            (y) =>
                                DropdownMenuItem(value: y, child: Text('$y')),
                          )
                          .toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 160,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (int i = 0; i < 12; i++) ...[
                    _buildBar(
                      (monthlyCounts[i] / maxCount) * 120,
                      120,
                      _getMonthLabelAbsolute(i),
                      monthlyCounts[i] > 0
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withValues(alpha: 0.5),
                    ),
                    if (i < 11) const SizedBox(width: 16),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(double height, double maxBox, String label, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              width: 24,
              height: maxBox,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ),
            Container(
              width: 24,
              height: height,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStreakCard(int globalStreak) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.flash_on, color: cs.primary, size: 28),
          const SizedBox(height: 16),
          Text(
            'GLOBAL STREAK',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
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
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              Text(
                ' Days',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            globalStreak > 0
                ? 'You are doing great!'
                : 'Start your engine today.',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedCard(int totalCompleted, int lastMonthCompleted) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COMPLETED HABITS',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$totalCompleted',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.history, color: cs.primary, size: 16),
              const SizedBox(width: 4),
              Text(
                '$lastMonthCompleted ',
                style: TextStyle(
                  color: cs.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'in the last 30 days',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapCard(List<Habit> habits) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.06),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Activity\nHeatmap',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Aggregate consistency across all tracked metrics.',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Text(
                    'LESS',
                    style: TextStyle(
                      fontSize: 8,
                      color: const Color(0xFF9BE9A8),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 4),
                  _buildLegendSquare(
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  Builder(
                    builder: (context) {
                      Color baseColor = const Color(
                        0xFF216E39,
                      ); // GitHub Dark Green
                      if (_selectedViewMode != 'Overview') {
                        final h = habits.firstWhere(
                          (h) => h.id == _selectedViewMode,
                        );
                        baseColor = Color(h.colorValue);
                      }

                      return Row(
                        children: [
                          if (_selectedViewMode == 'Overview') ...[
                            _buildLegendSquare(
                              const Color(0xFF9BE9A8),
                            ), // Level 1
                            _buildLegendSquare(
                              const Color(0xFF40C463),
                            ), // Level 2
                            _buildLegendSquare(
                              const Color(0xFF30A14E),
                            ), // Level 3
                            _buildLegendSquare(
                              const Color(0xFF216E39),
                            ), // Level 4
                          ] else ...[
                            _buildLegendSquare(
                              baseColor.withValues(alpha: 0.2),
                            ),
                            _buildLegendSquare(
                              baseColor.withValues(alpha: 0.5),
                            ),
                            _buildLegendSquare(
                              baseColor.withValues(alpha: 0.8),
                            ),
                            _buildLegendSquare(baseColor),
                          ],
                        ],
                      );
                    },
                  ),

                  const SizedBox(width: 4),
                  Text(
                    'MORE',
                    style: TextStyle(
                      fontSize: 8,
                      color: const Color(0xFF216E39),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildRealHeatmapGrid(habits),
        ],
      ),
    );
  }

  Widget _buildLegendSquare(Color color) {
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  Widget _buildRealHeatmapGrid(List<Habit> habits) {
    const int cols = 20;
    const int rows = 5;
    final today = DateTime.now();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (int i = 0; i < cols; i++)
              Column(
                children: [
                  for (int j = 0; j < rows; j++)
                    Builder(
                      builder: (context) {
                        int daysAgo =
                            ((cols - 1 - i) * rows) + ((rows - 1 - j));
                        DateTime date = today.subtract(Duration(days: daysAgo));
                        String dStr = _formatDate(date);

                        int count = 0;
                        for (final h in habits) {
                          if (h.dailyRecords[dStr]?.isCompleted == true)
                            count++;
                        }

                        Color baseColor = const Color(
                          0xFF216E39,
                        ); // GitHub Green
                        if (_selectedViewMode != 'Overview') {
                          final h = habits.firstWhere(
                            (h) => h.id == _selectedViewMode,
                          );
                          baseColor = Color(h.colorValue);
                        }

                        Color color =
                            Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest;

                        if (count > 0) {
                          if (_selectedViewMode == 'Overview') {
                            if (count == 1)
                              color = const Color(0xFF9BE9A8);
                            else if (count == 2)
                              color = const Color(0xFF40C463);
                            else if (count == 3)
                              color = const Color(0xFF30A14E);
                            else if (count >= 4)
                              color = const Color(0xFF216E39);
                          } else {
                            color = baseColor;
                          }
                        }

                        return Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.only(bottom: 3),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      },
                    ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _getMonthLabel(3),
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _getMonthLabel(2),
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _getMonthLabel(1),
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _getMonthLabel(0),
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 10),
          ],
        ),
      ],
    );
  }

  Widget _buildAchievementsGrid(int globalStreak, int totalCompleted) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.1,
      children: [
        _buildAchievementBadge(
          Icons.verified,
          '7-DAY STREAK',
          'First week complete',
          globalStreak >= 7,
        ),
        _buildAchievementBadge(
          Icons.star,
          'HABIT MASTER',
          '50 Habits completed',
          totalCompleted >= 50,
        ),
        _buildAchievementBadge(
          Icons.timer,
          'EARLY BIRD',
          'Current streak > 10',
          globalStreak > 10,
        ),
        _buildAchievementBadge(
          Icons.emoji_events,
          'CENTURION',
          '100 Habits Milestone',
          totalCompleted >= 100,
        ),
        _buildAchievementBadge(
          Icons.bolt,
          'MOMENTUM',
          '30-Day Streak',
          globalStreak >= 30,
        ),
        _buildAchievementBadge(
          Icons.workspace_premium,
          'APEX HABIT',
          '365 Day Streak',
          globalStreak >= 365,
        ),
      ],
    );
  }

  Widget _buildAchievementBadge(
    IconData icon,
    String title,
    String subtitle,
    bool earned,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.06),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  earned
                      ? Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.5)
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color:
                  earned
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color:
                  earned
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatFullDate(DateTime date) {
    const months = [
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _buildHabitInfoCard(Habit habit) {
    final cs = Theme.of(context).colorScheme;
    final habitColor = Color(habit.colorValue);
    final hasReminder =
        habit.reminderHour != null && habit.reminderMinute != null;

    String reminderText = 'No reminder set';
    if (hasReminder) {
      final time = TimeOfDay(
        hour: habit.reminderHour!,
        minute: habit.reminderMinute!,
      );
      reminderText = MaterialLocalizations.of(context).formatTimeOfDay(time);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Habit emoji + color row
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: habitColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    habit.iconEmoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                    if (habit.description.isNotEmpty)
                      Text(
                        habit.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _toggleToday(habit),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color:
                          habit
                                      .dailyRecords[_formatDate(DateTime.now())]
                                      ?.isCompleted ==
                                  true
                              ? habitColor
                              : habitColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: habitColor.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 28,
                      color:
                          habit
                                      .dailyRecords[_formatDate(DateTime.now())]
                                      ?.isCompleted ==
                                  true
                              ? Colors.white
                              : habitColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Info rows
          _buildInfoRow(
            Icons.calendar_today_outlined,
            'Date Added',
            _formatFullDate(habit.createdAt),
            habitColor,
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            hasReminder
                ? Icons.notifications_active_outlined
                : Icons.notifications_off_outlined,
            'Daily Reminder',
            reminderText,
            hasReminder ? habitColor : Colors.grey,
          ),
          const SizedBox(height: 10),
          // _buildInfoRow(
          //   Icons.today_outlined,
          //   'Days Tracked',
          //   '${DateTime.now().difference(habit.createdAt).inDays + 1} days',
          //   habitColor,
          // ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
      ],
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
    '🏋️',
    '🏃',
    '🚴',
    '🤺',
    '🧘',
    '🚼',
    '💧',
    '🥱',
    '💤',
    '🧬',
    '📚',
    '📝',
    '💻',
    '🎓',
    '🔬',
    '📈',
    '💼',
    '✅',
    '🏆',
    '💬',
    '🥗',
    '☕',
    '🍎',
    '🍿',
    '🍺',
    '🚫',
    '💰',
    '🎨',
    '🎵',
    '🎧',
    '🌱',
    '🌻',
    '🦋',
    '🌍',
    '✨',
    '🔥',
    '🌙',
    '☀️',
    '🧐',
    '💫',
    '👊',
    '🤝',
    '💖',
    '🙏',
    '🎉',
    '🚀',
    '🎯',
    '🔑',
    '🐾',
    '👩‍💻',
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
                          if (picked != null)
                            setState(() => reminderTime = picked);
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
                                  MaterialLocalizations.of(
                                    context,
                                  ).formatTimeOfDay(reminderTime),
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
                                            color: Colors.white,
                                            width: 3,
                                          )
                                          : null,
                                  boxShadow:
                                      selectedColor == c
                                          ? [
                                            BoxShadow(
                                              color: Color(c).withOpacity(0.5),
                                              blurRadius: 8,
                                            ),
                                          ]
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
                      final ok =
                          await NotificationService.requestReminderPermissions();
                      if (!context.mounted) return;
                      if (!ok) {
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
}
