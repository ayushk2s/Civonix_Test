import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';
import '../../domain/entities/user.dart';

class AuthState {
  final bool isLoading;
  final UserEntity? user;
  final String? error;
  final bool isAuthenticated;

  const AuthState({
    this.isLoading = false,
    this.user,
    this.error,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    bool? isLoading,
    UserEntity? user,
    String? error,
    bool? isAuthenticated,
  }) =>
      AuthState(
        isLoading: isLoading ?? this.isLoading,
        user: user ?? this.user,
        error: error,
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      );
}

class AuthViewModel extends StateNotifier<AuthState> {
  final ApiClient _api;

  AuthViewModel(this._api) : super(const AuthState()) {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    if (await _api.hasToken()) {
      await loadProfile();
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _api.post(Endpoints.login, data: {
        'email': email,
        'password': password,
      }) as Map<String, dynamic>;
      await _api.saveTokens(
        data['access_token'] as String,
        data['refresh_token'] as String,
      );
      await loadProfile();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> register(String username, String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final raw = await _api.post(Endpoints.register, data: {
        'username': username,
        'email': email,
        'password': password,
      });
      debugPrint('[Auth] register response type: ${raw.runtimeType}  value: $raw');
      final data = raw as Map<String, dynamic>;
      await _api.saveTokens(
        data['access_token'] as String,
        data['refresh_token'] as String,
      );
      await loadProfile();
      return true;
    } catch (e, st) {
      debugPrint('[Auth] register error: $e\n$st');
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> loadProfile() async {
    if (!await _api.hasToken()) {
      state = state.copyWith(isLoading: false, isAuthenticated: false);
      return;
    }
    try {
      final raw = await _api.get(Endpoints.me);
      debugPrint('[Auth] /me response type: ${raw.runtimeType}  value: $raw');
      final data = raw as Map<String, dynamic>;
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: UserEntity(
          id: data['id']?.toString() ?? '',
          username: data['username'] as String,
          email: data['email'] as String,
          displayName: data['display_name'] as String?,
          avatarUrl: data['avatar_url'] as String?,
          country: data['country'] as String?,
          stateRegion: data['state_region'] as String?,
          isPro: data['is_pro'] as bool? ?? false,
          isPublic: data['is_public'] as bool? ?? true,
          streakDays: (data['streak_days'] as num?)?.toInt() ?? 0,
          totalPredictions: (data['total_predictions'] as num?)?.toInt() ?? 0,
          correctPredictions: (data['correct_predictions'] as num?)?.toInt() ?? 0,
        ),
      );
    } catch (e, st) {
      debugPrint('[Auth] loadProfile error: $e\n$st');
      state = state.copyWith(isLoading: false, isAuthenticated: false);
    }
  }

  Future<void> logout() async {
    await _api.clearTokens();
    state = const AuthState();
  }
}

final authViewModelProvider =
    StateNotifierProvider<AuthViewModel, AuthState>((ref) {
  return AuthViewModel(ApiClient());
});
