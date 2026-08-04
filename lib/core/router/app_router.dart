import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/app_empty_state.dart';
import '../../presentation/navigation/main_shell.dart';
import '../../presentation/screens/habits/habit_detail_screen.dart';
import '../../presentation/screens/analytics/analytics_screen.dart';
import '../../presentation/screens/habits/habit_editor_screen.dart';
import '../../presentation/screens/habits/habits_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/journal/journal_detail_screen.dart';
import '../../presentation/screens/journal/journal_editor_screen.dart';
import '../../presentation/screens/journal/journal_list_screen.dart';
import '../../presentation/screens/notes/note_detail_screen.dart';
import '../../presentation/screens/notes/note_editor_screen.dart';
import '../../presentation/screens/notes/notes_screen.dart';
import '../../presentation/screens/search/search_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/screens/timeline/timeline_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Route table. Editors/details are pushed full-screen above the shell.
final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/home',
  // Catches unknown routes and builder exceptions so malformed deep links
  // show a friendly screen instead of crashing the app.
  errorBuilder: (context, state) => const _RouteErrorScreen(),
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MainShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/home', builder: (c, s) => const HomeScreen())],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/journal', builder: (c, s) => const JournalListScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/habits', builder: (c, s) => const HabitsScreen())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/notes', builder: (c, s) => const NotesScreen())],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/timeline', builder: (c, s) => const TimelineScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/search',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => _fadeSlidePage(state, const SearchScreen()),
    ),
    GoRoute(
      path: '/analytics',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) =>
          _fadeSlidePage(state, const AnalyticsScreen()),
    ),
    GoRoute(
      path: '/journal/editor',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => _fadeSlidePage(
        state,
        JournalEditorScreen(id: int.tryParse(state.uri.queryParameters['id'] ?? '')),
      ),
    ),
    GoRoute(
      path: '/journal/detail/:id',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => _fadeSlidePage(
        state,
        JournalDetailScreen(id: _routeId(state) ?? -1),
      ),
    ),
    GoRoute(
      path: '/habit/editor',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => _fadeSlidePage(
        state,
        HabitEditorScreen(id: int.tryParse(state.uri.queryParameters['id'] ?? '')),
      ),
    ),
    GoRoute(
      path: '/habit/detail/:id',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => _fadeSlidePage(
        state,
        HabitDetailScreen(id: _routeId(state) ?? -1),
      ),
    ),
    GoRoute(
      path: '/note/editor',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => _fadeSlidePage(
        state,
        NoteEditorScreen(id: int.tryParse(state.uri.queryParameters['id'] ?? '')),
      ),
    ),
    GoRoute(
      path: '/note/detail/:id',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => _fadeSlidePage(
        state,
        NoteDetailScreen(id: _routeId(state) ?? -1),
      ),
    ),
  ],
);

/// Parses the `:id` path parameter safely.
///
/// Returns `null` for missing or non-numeric values so detail screens render
/// their "not found" state instead of crashing on a malformed deep link.
int? _routeId(GoRouterState state) =>
    int.tryParse(state.pathParameters['id'] ?? '');

/// Shown by the router when a location can't be resolved or a builder threw.
class _RouteErrorScreen extends StatelessWidget {
  const _RouteErrorScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppEmptyState(
        icon: Icons.error_outline,
        title: 'Page not found',
        subtitle: 'This page does not exist or could not be opened.',
        actionLabel: 'Go home',
        onAction: () => context.go('/home'),
      ),
    );
  }
}

/// Smooth fade + slide page transition for pushed screens.
Page<void> _fadeSlidePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
