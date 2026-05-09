import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../../models/leaderboard_model.dart';

class LeaderboardRemoteDatasource {
  final ApiClient _api;
  LeaderboardRemoteDatasource(this._api);

  Future<LeaderboardModel> getLeaderboard({
    String scope = 'global',
    String scopeValue = 'global',
    int limit = 100,
  }) async {
    final data = await _api.get(
      Endpoints.leaderboard(scope, scopeValue),
      queryParams: {'limit': limit},
    ) as Map<String, dynamic>;
    return LeaderboardModel.fromJson(data);
  }
}
