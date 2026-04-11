import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/habits/logic/habit_provider.dart';

class UserState {
  final String name;
  final bool hasCompletedOnboarding;
  
  UserState({required this.name, required this.hasCompletedOnboarding});
  
  UserState copyWith({String? name, bool? hasCompletedOnboarding}) {
    return UserState(
      name: name ?? this.name,
      hasCompletedOnboarding: hasCompletedOnboarding ?? this.hasCompletedOnboarding,
    );
  }
}

final userProvider = StateNotifierProvider<UserNotifier, UserState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return UserNotifier(prefs);
});

class UserNotifier extends StateNotifier<UserState> {
  final SharedPreferences _prefs;
  static const _nameKey = 'user_name';
  static const _onboardingKey = 'has_completed_onboarding';

  UserNotifier(this._prefs) 
    : super(UserState(
        name: _prefs.getString(_nameKey) ?? 'Friend',
        hasCompletedOnboarding: _prefs.getBool(_onboardingKey) ?? false,
      ));

  Future<void> setName(String newName) async {
    state = state.copyWith(name: newName);
    await _prefs.setString(_nameKey, newName);
  }

  Future<void> completeOnboarding() async {
    state = state.copyWith(hasCompletedOnboarding: true);
    await _prefs.setBool(_onboardingKey, true);
  }

  Future<void> reset() async {
    state = UserState(name: 'Friend', hasCompletedOnboarding: false);
    await _prefs.remove(_nameKey);
    await _prefs.remove(_onboardingKey);
  }
}
