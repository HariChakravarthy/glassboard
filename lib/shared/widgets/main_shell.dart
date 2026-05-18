import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/app_providers.dart';
import 'offline_banner.dart';

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;

  static const _routes = ['/dashboard', '/handshake/inbox', '/files', '/notifications'];

  void _onTap(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
    context.go(_routes[index]);
  }

  String _locationToIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc.startsWith('/handshake')) return '1';
    if (loc.startsWith('/files')) return '2';
    if (loc.startsWith('/notifications')) return '3';
    return '0'; // dashboard
  }

  @override
  Widget build(BuildContext context) {
    // Sync tab index with current route
    final idxStr = _locationToIndex(context);
    final routeIdx = int.parse(idxStr);
    if (routeIdx != _currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentIndex = routeIdx);
      });
    }

    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.valueOrNull;
    final unreadAsync = user != null
        ? ref.watch(unreadCountProvider(user.uid))
        : const AsyncData(0);
    final unreadCount = unreadAsync.valueOrNull ?? 0;

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
              children: [
                _NavItem(
                  icon: Icons.grid_view_rounded,
                  label: 'MODULES',
                  selected: _currentIndex == 0,
                  onTap: () => _onTap(0),
                ),
                _NavItem(
                  icon: Icons.swap_horiz_rounded,
                  label: 'HANDSHAKE',
                  selected: _currentIndex == 1,
                  onTap: () => _onTap(1),
                ),
                _NavItem(
                  icon: Icons.folder_outlined,
                  label: 'FILES',
                  selected: _currentIndex == 2,
                  onTap: () => _onTap(2),
                ),
                _NavItem(
                  icon: Icons.notifications_outlined,
                  label: 'ALERTS',
                  selected: _currentIndex == 3,
                  onTap: () => _onTap(3),
                  badge: unreadCount,
                ),
              ],
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
  final int badge;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.primary : AppTheme.textMuted;

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
                        ? AppTheme.primary.withAlpha(26)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                if (badge > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppTheme.danger,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        badge > 9 ? '9+' : '$badge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
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
