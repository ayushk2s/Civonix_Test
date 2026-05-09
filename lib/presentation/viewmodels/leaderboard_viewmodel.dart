import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../data/datasources/remote/leaderboard_remote_datasource.dart';
import '../../domain/entities/leaderboard_entry.dart';

class LeaderboardState {
  final bool isLoading;
  final LeaderboardEntity? leaderboard;
  final String scope;
  final String scopeValue;
  final String? error;

  const LeaderboardState({
    this.isLoading = false,
    this.leaderboard,
    this.scope = 'global',
    this.scopeValue = 'global',
    this.error,
  });

  LeaderboardState copyWith({
    bool? isLoading,
    LeaderboardEntity? leaderboard,
    String? scope,
    String? scopeValue,
    String? error,
  }) =>
      LeaderboardState(
        isLoading: isLoading ?? this.isLoading,
        leaderboard: leaderboard ?? this.leaderboard,
        scope: scope ?? this.scope,
        scopeValue: scopeValue ?? this.scopeValue,
        error: error,
      );
}

class LeaderboardViewModel extends StateNotifier<LeaderboardState> {
  final LeaderboardRemoteDatasource _ds;

  LeaderboardViewModel(this._ds) : super(const LeaderboardState());

  Future<void> load({String scope = 'global', String scopeValue = 'global'}) async {
    state = state.copyWith(
      isLoading: true, error: null, scope: scope, scopeValue: scopeValue,
    );
    try {
      final model = await _ds.getLeaderboard(scope: scope, scopeValue: scopeValue);
      state = state.copyWith(isLoading: false, leaderboard: model.toEntity());
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> changeScope(String scope, String scopeValue) async {
    await load(scope: scope, scopeValue: scopeValue);
  }
}

final leaderboardViewModelProvider =
    StateNotifierProvider<LeaderboardViewModel, LeaderboardState>((ref) {
  return LeaderboardViewModel(LeaderboardRemoteDatasource(ApiClient()));
});
