import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../../models/portfolio_model.dart';

class PortfolioRemoteDatasource {
  final ApiClient _api;
  PortfolioRemoteDatasource(this._api);

  Future<PortfolioSummaryModel> getSummary() async {
    final data = await _api.get(Endpoints.portfolioSummary) as Map<String, dynamic>;
    return PortfolioSummaryModel.fromJson(data);
  }

  Future<List<ExchangeAccountModel>> getExchangeAccounts() async {
    final data = await _api.get(Endpoints.listExchanges) as List;
    return data.map((e) => ExchangeAccountModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ExchangeAccountModel> connectExchange({
    required String exchange,
    required String apiKey,
    required String apiSecret,
    String? apiPassphrase,
    String label = 'My Account',
  }) async {
    final body = <String, dynamic>{
      'exchange': exchange,
      'api_key': apiKey,
      'api_secret': apiSecret,
      'label': label,
    };
    if (apiPassphrase != null) body['api_passphrase'] = apiPassphrase;
    final data = await _api.post(Endpoints.connectExchange, data: body)
        as Map<String, dynamic>;
    return ExchangeAccountModel.fromJson(data);
  }

  Future<void> disconnectExchange(String accountId) async {
    await _api.delete(Endpoints.disconnectExchange(accountId));
  }

  Future<List<TradeModel>> getTrades({int limit = 100, int offset = 0}) async {
    final data = await _api.get(Endpoints.trades, queryParams: {
      'limit': limit,
      'offset': offset,
    }) as List;
    return data.map((e) => TradeModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> triggerSync(String accountId, {bool full = false}) async {
    await _api.post(
      Endpoints.syncAccount(accountId),
      queryParams: full ? {'full': 'true'} : null,
    );
  }
}
