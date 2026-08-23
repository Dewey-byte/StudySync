import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/assignments/presentation/pages/assignments_page.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/controllers/auth_state.dart';
import '../../features/auth/presentation/pages/app_lock_page.dart';
import '../../features/auth/presentation/pages/sign_in_page.dart';
import '../../features/auth/presentation/pages/sign_up_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/groups/presentation/pages/group_detail_page.dart';
import '../../features/groups/presentation/pages/groups_page.dart';
import '../../features/schedule/presentation/pages/schedule_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../shell/home_shell.dart';
import 'routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthChangeNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoute.splash.path,
    refreshListenable: refresh,
    redirect: (context, state) => _guard(ref, state.matchedLocation),
    routes: <RouteBase>[
      GoRoute(
        path: AppRoute.splash.path,
        name: AppRoute.splash.name,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoute.signIn.path,
        name: AppRoute.signIn.name,
        builder: (context, state) => const SignInPage(),
      ),
      GoRoute(
        path: AppRoute.signUp.path,
        name: AppRoute.signUp.name,
        builder: (context, state) => const SignUpPage(),
      ),
      GoRoute(
        path: AppRoute.lock.path,
        name: AppRoute.lock.name,
        builder: (context, state) => const AppLockPage(),
      ),
      GoRoute(
        path: AppRoute.settings.path,
        name: AppRoute.settings.name,
        builder: (context, state) => const SettingsPage(),
      ),
      // Each tab keeps its own navigation stack and scroll position.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoute.dashboard.path,
                name: AppRoute.dashboard.name,
                builder: (context, state) => const DashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoute.assignments.path,
                name: AppRoute.assignments.name,
                builder: (context, state) => const AssignmentsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoute.schedule.path,
                name: AppRoute.schedule.name,
                builder: (context, state) => const SchedulePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoute.groups.path,
                name: AppRoute.groups.name,
                builder: (context, state) => const GroupsPage(),
                routes: <RouteBase>[
                  GoRoute(
                    path: ':groupId',
                    name: AppRoute.groupDetail.name,
                    builder: (context, state) => GroupDetailPage(
                      groupId: state.pathParameters['groupId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Single source of truth for which screens each session state may reach.
///
/// Centralising this here means a new screen cannot accidentally be reachable
/// while the app is locked or signed out.
String? _guard(Ref ref, String location) {
  final status = ref.read(authControllerProvider).status;

  const publicRoutes = <String>{'/sign-in', '/sign-up'};
  final isPublic = publicRoutes.contains(location);
  final isSplash = location == AppRoute.splash.path;
  final isLock = location == AppRoute.lock.path;

  return switch (status) {
    AuthStatus.unknown => isSplash ? null : AppRoute.splash.path,
    AuthStatus.unauthenticated => isPublic ? null : AppRoute.signIn.path,
    AuthStatus.locked => isLock ? null : AppRoute.lock.path,
    AuthStatus.authenticated =>
      isPublic || isSplash || isLock ? AppRoute.dashboard.path : null,
  };
}

/// Bridges Riverpod's auth state to go_router's [Listenable]-based refresh.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    _subscription = ref.listen<AuthState>(
      authControllerProvider,
      (previous, next) {
        if (previous?.status != next.status) notifyListeners();
      },
    );
  }

  late final ProviderSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
