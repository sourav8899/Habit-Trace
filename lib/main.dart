import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';
import 'features/home/screens/home_screen.dart';
import 'features/habits/logic/habit_provider.dart';
import 'core/theme/theme_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';
import 'core/services/widget_service.dart';
import 'core/providers/user_provider.dart';
import 'features/onboarding/screens/onboarding_screen.dart';

/// Global callback that HomeScreen registers so main.dart can tell it
/// to switch to the Stats tab and select a particular habit.
/// Using a static function avoids needing a GlobalKey across files.
void Function(String habitId)? onNavigateToHabitStats;

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

class _HabitFlowAppState extends ConsumerState<HabitFlowApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  Uri? _pendingUri; // Stores cold-launch URI until navigator is ready

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Navigate to habit stats when user taps a scheduled notification
    NotificationService.onNotificationTap = (habitId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onNavigateToHabitStats?.call(habitId);
      });
    };

    // Handle widget tap that launched the app cold — store URI and retry after build
    HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
      if (uri != null) {
        _pendingUri = uri;
        // Attempt to navigate once the navigator is mounted
        WidgetsBinding.instance.addPostFrameCallback((_) => _tryFlushPendingUri());
      }
    });

    // Handle widget tap while app is already running (warm launch)
    HomeWidget.widgetClicked.listen(_handleUri);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Sync habit updates from Native Widget to Flutter app
      ref.read(habitProvider.notifier).syncWithWidget();
    }
  }

  /// Retries navigating to [_pendingUri] each frame until both the navigator
  /// AND HomeScreen's callback are ready. Caps at 120 retries (~2 seconds) to
  /// avoid an infinite loop if something truly goes wrong.
  int _flushRetries = 0;
  void _tryFlushPendingUri() {
    final uri = _pendingUri;
    if (uri == null) return;
    // Both the navigator AND HomeScreen's callback must be ready
    if (_navigatorKey.currentState != null && onNavigateToHabitStats != null) {
      _pendingUri = null;
      _flushRetries = 0;
      _handleUri(uri);
    } else if (_flushRetries < 120) {
      _flushRetries++;
      // Retry next rendered frame
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryFlushPendingUri());
    }
  }

  void _handleUri(Uri? uri) {
    if (uri == null) return;

    // Prevent widget deep links from bypassing the onboarding flow
    final userState = ref.read(userProvider);
    if (!userState.hasCompletedOnboarding) return;

    if (uri.scheme == 'habitflow' && uri.host == 'habit') {
      final habitId =
          uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      if (habitId != null && habitId.isNotEmpty) {
        if (onNavigateToHabitStats != null) {
          // App is running — switch tab in-place, no new route
          onNavigateToHabitStats!(habitId);
        } else {
            // HomeScreen not yet registered (cold launch still initialising);
            // store and retry — _tryFlushPendingUri will call us back.
            _pendingUri = uri;
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _tryFlushPendingUri());
          }
      }
    } else if (uri.scheme == 'habitflow' && uri.host == 'add_habit') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const HomeScreen(openAddHabit: true),
          ),
          (route) => false,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final userState = ref.watch(userProvider);

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Habit Trace',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: userState.hasCompletedOnboarding
          ? HomeScreen(
              initialHabitId: _pendingUri?.host == 'habit' &&
                      (_pendingUri?.pathSegments.isNotEmpty ?? false)
                  ? _pendingUri!.pathSegments.first
                  : null,
            )
          : const OnboardingScreen(),
    );
  }
}
