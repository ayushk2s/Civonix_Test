import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../viewmodels/portfolio_viewmodel.dart';
import '../../widgets/common/gradient_button.dart';

class ConnectExchangeScreen extends ConsumerStatefulWidget {
  const ConnectExchangeScreen({super.key});

  @override
  ConsumerState<ConnectExchangeScreen> createState() =>
      _ConnectExchangeScreenState();
}

class _ConnectExchangeScreenState
    extends ConsumerState<ConnectExchangeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiKeyCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();
  final _passphraseCtrl = TextEditingController();
  bool _obscureSecret = true;
  bool _obscurePassphrase = true;
  String _selectedExchange = 'binance';

  static const _exchanges = [
    (id: 'binance', name: 'Binance', icon: '₿'),
    (id: 'bybit', name: 'Bybit', icon: 'B'),
    (id: 'kucoin', name: 'KuCoin', icon: 'K'),
  ];

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _secretCtrl.dispose();
    _passphraseCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(portfolioViewModelProvider.notifier).connectExchange(
          exchange: _selectedExchange,
          apiKey: _apiKeyCtrl.text.trim(),
          apiSecret: _secretCtrl.text.trim(),
          apiPassphrase: _selectedExchange == 'kucoin'
              ? _passphraseCtrl.text.trim()
              : null,
        );
    if (ok && mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(portfolioViewModelProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Connect Exchange'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Security Notice
              Container(
                padding: const EdgeInsets.all(AppSizes.md),
                decoration: BoxDecoration(
                  color: AppColors.gainMuted,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  border:
                      Border.all(color: AppColors.gain.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_rounded, color: AppColors.gain, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Read-only access only. We cannot trade or withdraw on your behalf.',
                        style: TextStyle(
                            color: AppColors.gain,
                            fontSize: 12,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms),
              const SizedBox(height: AppSizes.xl),

              // Exchange selector
              Text('Select Exchange',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSizes.sm),
              Row(
                children: _exchanges.map((e) {
                  final selected = _selectedExchange == e.id;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedExchange = e.id),
                        child: AnimatedContainer(
                          duration: 200.ms,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary.withValues(alpha: 0.15)
                                : AppColors.card,
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusMd),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.cardBorder,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                e.icon,
                                style: TextStyle(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.textMuted,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                e.name,
                                style: TextStyle(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ).animate().fadeIn(duration: 300.ms, delay: 100.ms),
              const SizedBox(height: AppSizes.xl),

              // API Key
              Text('API Credentials',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSizes.sm),
              TextFormField(
                controller: _apiKeyCtrl,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  hintText: 'Paste your read-only API key',
                  prefixIcon: Icon(Icons.key_rounded, size: 18),
                ),
                validator: (v) =>
                    v == null || v.length < 10 ? 'Enter a valid API key' : null,
              ).animate().fadeIn(duration: 300.ms, delay: 150.ms),
              const SizedBox(height: AppSizes.md),

              TextFormField(
                controller: _secretCtrl,
                obscureText: _obscureSecret,
                decoration: InputDecoration(
                  labelText: 'API Secret',
                  hintText: 'Paste your API secret',
                  prefixIcon:
                      const Icon(Icons.lock_outline_rounded, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureSecret
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                    ),
                    onPressed: () =>
                        setState(() => _obscureSecret = !_obscureSecret),
                  ),
                ),
                validator: (v) =>
                    v == null || v.length < 10 ? 'Enter a valid secret' : null,
              ).animate().fadeIn(duration: 300.ms, delay: 200.ms),

              if (_selectedExchange == 'kucoin') ...[
                const SizedBox(height: AppSizes.md),
                TextFormField(
                  controller: _passphraseCtrl,
                  obscureText: _obscurePassphrase,
                  decoration: InputDecoration(
                    labelText: 'API Passphrase',
                    hintText: 'Enter your KuCoin passphrase',
                    prefixIcon:
                        const Icon(Icons.password_rounded, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassphrase
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                      ),
                      onPressed: () => setState(
                          () => _obscurePassphrase = !_obscurePassphrase),
                    ),
                  ),
                  validator: (v) => _selectedExchange == 'kucoin' &&
                          (v == null || v.isEmpty)
                      ? 'Passphrase is required for KuCoin'
                      : null,
                ).animate().fadeIn(duration: 200.ms),
              ],

              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSizes.sm),
                  child: Text(
                    state.error!,
                    style: const TextStyle(
                        color: AppColors.loss, fontSize: 13),
                  ),
                ),

              const SizedBox(height: AppSizes.xl),

              GradientButton(
                label: 'Connect & Sync',
                isLoading: state.isLoading,
                onTap: _submit,
                prefix: const Icon(Icons.link_rounded, size: 18),
              ).animate().fadeIn(duration: 300.ms, delay: 250.ms),
              const SizedBox(height: AppSizes.md),

              // Instructions
              _HowToCard(exchange: _selectedExchange)
                  .animate()
                  .fadeIn(duration: 300.ms, delay: 300.ms),
            ],
          ),
        ),
      ),
    );
  }
}

class _HowToCard extends StatelessWidget {
  final String exchange;
  const _HowToCard({required this.exchange});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.help_outline_rounded,
                  color: AppColors.primary, size: 18),
              SizedBox(width: 8),
              Text(
                'How to get API keys',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          ..._steps(exchange).map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          s.$1,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.$2,
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 6),
          const Text(
            'Enable "Read Info" and "Read Trade History" only. Never enable withdrawals.',
            style: TextStyle(
                color: AppColors.warning,
                fontSize: 11,
                fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  List<(String, String)> _steps(String exchange) {
    if (exchange == 'binance') {
      return [
        ('1', 'Log in to Binance → Profile → API Management'),
        ('2', 'Click "Create API" and set a label'),
        ('3', 'Select "System generated" key type'),
        ('4', 'Enable only "Read Info" and "Read Trade History"'),
        ('5', 'Copy both API Key and Secret Key here'),
      ];
    } else if (exchange == 'bybit') {
      return [
        ('1', 'Log in to Bybit → Profile → API Management'),
        ('2', 'Click "Create New Key"'),
        ('3', 'Set permissions to "Read-Only"'),
        ('4', 'Copy the API Key and Secret'),
      ];
    } else {
      return [
        ('1', 'Log in to KuCoin → Profile → API Management'),
        ('2', 'Click "Create API" and set a name'),
        ('3', 'Set API restrictions to "General" (read-only)'),
        ('4', 'Set a passphrase and note it down'),
        ('5', 'Copy the API Key, Secret, and Passphrase here'),
      ];
    }
  }
}
