import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';
import 'features/home/screens/home_screen.dart';
import 'features/home/screens/stats_screen.dart';
import 'features/habits/logic/habit_provider.dart';
import 'core/theme/theme_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';
import 'core/services/widget_service.dart';
import 'core/providers/user_provider.dart';
import 'features/onboarding/screens/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize local storage eagerly before runApp
  final prefs = await SharedPreferences.getInstance();

  // Initialize home screen widget bridge
  await WidgetService.init();
  await NotificationService.init();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, 
      statusBarIconBrightness: Brightness.dark,
    )
  );
  
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const HabitFlowApp(),
    ),
  );
}

class HabitFlowApp extends ConsumerStatefulWidget {
  const HabitFlowApp({super.key});

  @override
  ConsumerState<HabitFlowApp> createState() => _HabitFlowAppState();
}

class _HabitFlowAppState extends ConsumerState<HabitFlowApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();

    // Navigate to habit stats when user taps a scheduled notification
    NotificationService.onNotificationTap = (habitId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => StatsScreen(initialHabitId: habitId),
          ),
        );
      });
    };

    // Handle widget tap that launched the app cold
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleUri);

    // Handle widget tap while app is already running
    HomeWidget.widgetClicked.listen(_handleUri);
  }

  void _handleUri(Uri? uri) {
    if (uri == null) return;
    // Expected URI: habitflow://habit/{habitId}
    if (uri.scheme == 'habitflow' && uri.host == 'habit') {
      final habitId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      if (habitId != null && habitId.isNotEmpty) {
        // Wait a frame so navigator is ready
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => StatsScreen(initialHabitId: habitId),
            ),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final userState = ref.watch(userProvider);

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'HabitTrace',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: userState.hasCompletedOnboarding
          ? const HomeScreen()
          : const OnboardingScreen(),
    );
  }
}
