import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/auth_provider.dart';
import 'offline_banner.dart';

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _NavItemData {
  final String route;
  final IconData icon;
  final String label;
  final Color selectedColor;

  const _NavItemData({
    required this.route,
    required this.icon,
    required this.label,
    required this.selectedColor,
  });
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;

  List<_NavItemData> _getNavItems(dynamic user) {
    if (user == null) {
      return const [
        _NavItemData(
          route: '/dashboard',
          icon: Icons.grid_view_rounded,
          label: 'MODULES',
          selectedColor: AppTheme.primary,
        ),
      ];
    }

    final items = <_NavItemData>[
      const _NavItemData(
        route: '/dashboard',
        icon: Icons.grid_view_rounded,
        label: 'MODULES',
        selectedColor: AppTheme.primary,
      ),
    ];

    // Handshake: lead and org_admin (not members)
    if (!user.isMember) {
      items.add(const _NavItemData(
        route: '/handshake/inbox',
        icon: Icons.handshake_outlined,
        label: 'HANDSHAKE',
        selectedColor: AppTheme.warning,
      ));
    }

    // Files: everyone
    items.add(const _NavItemData(
      route: '/files',
      icon: Icons.folder_shared_outlined,
      label: 'FILES',
      selectedColor: AppTheme.purple,
    ));

    // Users: only org_admin
    if (user.isOrgAdmin) {
      items.add(const _NavItemData(
        route: '/admin/users',
        icon: Icons.people_outline_rounded,
        label: 'USERS',
        selectedColor: AppTheme.orange,
      ));
    }

    return items;
  }

  List<String> _getRoutes(dynamic user) {
    return _getNavItems(user).map((item) => item.route).toList();
  }

  void _onTap(int index, dynamic user) {
    final routes = _getRoutes(user);
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
    context.go(routes[index]);
  }

  String _locationToIndex(BuildContext context, dynamic user) {
    final loc = GoRouterState.of(context).matchedLocation;
    final routes = _getRoutes(user);
    final idx = routes.indexWhere((r) {
      if (r == '/handshake/inbox') return loc.startsWith('/handshake');
      return loc.startsWith(r);
    });
    return idx >= 0 ? idx.toString() : '0';
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.valueOrNull;

    final navItems = _getNavItems(user);

    // Sync tab index with current route dynamically
    final idxStr = _locationToIndex(context, user);
    final routeIdx = int.parse(idxStr);
    if (routeIdx != _currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentIndex = routeIdx);
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: OfflineBanner(child: widget.child),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              children: navItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return _NavItem(
                  icon: item.icon,
                  label: item.label,
                  selected: _currentIndex == index,
                  onTap: () => _onTap(index, user),
                  selectedColor: item.selectedColor,
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? selectedColor;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = selectedColor ?? AppTheme.primary;
    final color = selected ? activeColor : AppTheme.textMuted;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: selected
                        ? activeColor.withAlpha(26)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: color,
                fontSize: 8,
                letterSpacing: 1.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                fontFamily: 'Space Mono',
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
