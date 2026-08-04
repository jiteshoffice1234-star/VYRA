import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/quick_add_sheet.dart';

/// Scaffold hosting the bottom navigation shell and a contextual FAB.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final index = navigationShell.currentIndex;

    return Scaffold(
      body: navigationShell,
      floatingActionButton: index == 4 || index == 5
          ? null
          : FloatingActionButton(
              heroTag: 'main_fab',
              onPressed: () => _onFabPressed(context, index),
              tooltip: 'Add',
              child: const Icon(Icons.add),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == index,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Journal',
          ),
          NavigationDestination(
            icon: Icon(Icons.repeat_outlined),
            selectedIcon: Icon(Icons.repeat),
            label: 'Habits',
          ),
          NavigationDestination(
            icon: Icon(Icons.sticky_note_2_outlined),
            selectedIcon: Icon(Icons.sticky_note_2),
            label: 'Notes',
          ),
          NavigationDestination(
            icon: Icon(Icons.timeline_outlined),
            selectedIcon: Icon(Icons.timeline),
            label: 'Timeline',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  void _onFabPressed(BuildContext context, int index) {
    switch (index) {
      case 0:
        showQuickAddSheet(context);
        break;
      case 1:
        context.push('/journal/editor');
        break;
      case 2:
        context.push('/habit/editor');
        break;
      case 3:
        context.push('/note/editor');
        break;
    }
  }
}
