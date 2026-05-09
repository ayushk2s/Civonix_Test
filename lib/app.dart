import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/auth/register_screen.dart';
import 'presentation/screens/connect_exchange/connect_exchange_screen.dart';
import 'presentation/screens/dashboard/dashboard_screen.dart';
import 'presentation/screens/ai_insights/ai_insights_screen.dart';
import 'presentation/screens/leaderboard/leaderboard_screen.dart';
import 'presentation/screens/news/news_screen.dart';
import 'presentation/screens/portfolio/analytics_screen.dart';
import 'presentation/screens/portfolio/portfolio_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'presentation/screens/splash/splash_screen.dart';

// ── Shell destinations ───────────────────────────────────────────────────────

final _shellNavigatorKey = GlobalKey<NavigatorState>();

final _router = GoRouter(
  initialLocation: '/splash',
  redirect: (context, state) {
    // Handled by SplashScreen — no redirect needed at router level
    return null;
  },
  routes: [
    GoRoute(
      path: '/splash',
      builder: (_, _) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (_, _) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (_, _) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/connect-exchange',
      builder: (_, _) => const ConnectExchangeScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (_, _) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/analytics',
      builder: (_, _) => const AnalyticsScreen(),
    ),

    // Bottom-nav shell
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => _AppShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/portfolio',
          builder: (_, _) => const PortfolioScreen(),
        ),
        GoRoute(
          path: '/ai',
          builder: (_, _) => const AiInsightsScreen(),
        ),
        GoRoute(
          path: '/leaderboard',
          builder: (_, _) => const LeaderboardScreen(),
        ),
        GoRoute(
          path: '/news',
          builder: (_, _) => const NewsScreen(),
        ),
      ],
    ),
  ],
);

// ── Bottom nav shell ─────────────────────────────────────────────────────────

class _AppShell extends StatelessWidget {
  final Widget child;
  const _AppShell({required this.child});

  static const _tabs = [
    (path: '/', icon: Icons.home_rounded, label: 'Home'),
    (path: '/portfolio', icon: Icons.account_balance_wallet_rounded, label: 'Portfolio'),
    (path: '/ai', icon: Icons.auto_awesome_rounded, label: 'AI'),
    (path: '/leaderboard', icon: Icons.leaderboard_rounded, label: 'Ranks'),
    (path: '/news', icon: Icons.newspaper_rounded, label: 'News'),
  ];

  int _currentIndex(String location) {
    if (location.startsWith('/portfolio')) return 1;
    if (location.startsWith('/ai')) return 2;
    if (location.startsWith('/leaderboard')) return 3;
    if (location.startsWith('/news')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final currentIndex = _currentIndex(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.cardBorder, width: 1),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              children: _tabs.asMap().entries.map((entry) {
                final i = entry.key;
                final tab = entry.value;
                final selected = i == currentIndex;

                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (!selected) context.go(tab.path);
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            tab.icon,
                            size: 22,
                            color: selected
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tab.label,
                          style: TextStyle(
                            color: selected
                                ? AppColors.primary
                                : AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Root app widget ──────────────────────────────────────────────────────────

class CivonixApp extends ConsumerWidget {
  const CivonixApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Civonix',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: _router,
    );
  }
}
