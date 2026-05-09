import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../data/datasources/remote/portfolio_remote_datasource.dart';
import '../../domain/entities/portfolio.dart';

class PortfolioState {
  final bool isLoading;
  final PortfolioSummaryEntity? summary;
  final List<ExchangeAccountEntity> accounts;
  final List<TradeEntity> trades;
  final String? error;

  const PortfolioState({
    this.isLoading = false,
    this.summary,
    this.accounts = const [],
    this.trades = const [],
    this.error,
  });

  PortfolioState copyWith({
    bool? isLoading,
    PortfolioSummaryEntity? summary,
    List<ExchangeAccountEntity>? accounts,
    List<TradeEntity>? trades,
    String? error,
  }) =>
      PortfolioState(
        isLoading: isLoading ?? this.isLoading,
        summary: summary ?? this.summary,
        accounts: accounts ?? this.accounts,
        trades: trades ?? this.trades,
        error: error,
      );
}

class PortfolioViewModel extends StateNotifier<PortfolioState> {
  final PortfolioRemoteDatasource _ds;

  PortfolioViewModel(this._ds) : super(const PortfolioState());

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, error: null);

    // Load accounts and summary independently — one failure must not hide the other
    PortfolioSummaryEntity? summary;
    List<ExchangeAccountEntity> accounts = [];

    await Future.wait([
      _ds.getSummary()
          .then((m) { summary = m.toEntity(); })
          .catchError((_) {}),
      _ds.getExchangeAccounts()
          .then((list) { accounts = list.map((a) => a.toEntity()).toList(); })
          .catchError((_) {}),
    ]);

    state = state.copyWith(
      isLoading: false,
      summary: summary,
      accounts: accounts,
    );
  }

  Future<void> loadSummary() async {
    try {
      final model = await _ds.getSummary();
      state = state.copyWith(summary: model.toEntity());
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> loadTrades() async {
    try {
      final models = await _ds.getTrades();
      state = state.copyWith(trades: models.map((m) => m.toEntity()).toList());
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<bool> connectExchange({
    required String exchange,
    required String apiKey,
    required String apiSecret,
    String? apiPassphrase,
    String label = 'My Account',
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _ds.connectExchange(
        exchange: exchange,
        apiKey: apiKey,
        apiSecret: apiSecret,
        apiPassphrase: apiPassphrase,
        label: label,
      );
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> syncAccount(String accountId, {bool full = false}) async {
    try {
      await _ds.triggerSync(accountId, full: full);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<bool> disconnectExchange(String accountId) async {
    try {
      await _ds.disconnectExchange(accountId);
      final updated = state.accounts.where((a) => a.id != accountId).toList();
      state = state.copyWith(accounts: updated);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

final portfolioViewModelProvider =
    StateNotifierProvider<PortfolioViewModel, PortfolioState>((ref) {
  return PortfolioViewModel(PortfolioRemoteDatasource(ApiClient()));
});
