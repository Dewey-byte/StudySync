import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bottom navigation wrapper around the four main sections.
class HomeShell extends StatelessWidget {
  const HomeShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  static const List<_Destination> _destinations = <_Destination>[
    _Destination('Home', Icons.home_outlined, Icons.home_rounded),
    _Destination('Tasks', Icons.checklist_outlined, Icons.checklist_rounded),
    _Destination(
      'Schedule',
      Icons.calendar_today_outlined,
      Icons.calendar_today_rounded,
    ),
    _Destination('Groups', Icons.groups_outlined, Icons.groups_rounded),
  ];

  void _onDestinationSelected(int index) {
    // Tapping the active tab pops it back to its first screen.
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: _destinations
            .map(
              (destination) => NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: destination.label,
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
