import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/module_model.dart';

/// Visualizes the module dependency chain as a scrollable graph.
/// Each module card shows its status, progress, and arrows to dependencies.
class DependencyGraph extends StatelessWidget {
  final List<ModuleModel> modules;
  final void Function(String moduleId) onModuleTap;

  const DependencyGraph({
    super.key,
    required this.modules,
    required this.onModuleTap,
  });

  @override
  Widget build(BuildContext context) {
    if (modules.isEmpty) return const SizedBox();

    // Build a map for quick lookup
    final moduleMap = {for (final m in modules) m.id: m};

    // Topological ordering: roots first (no dependencies)
    final levels = _buildLevels(modules, moduleMap);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: levels.asMap().entries.map((entry) {
            final levelIdx = entry.key;
            final level    = entry.value;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: level.map((m) =>
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _GraphNode(
                        module: m,
                        onTap: () => onModuleTap(m.id),
                      ),
                    ),
                  ).toList(),
                ),
                if (levelIdx < levels.length - 1)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: _Arrow(),
                  ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Assigns modules to levels based on dependency depth
  List<List<ModuleModel>> _buildLevels(
      List<ModuleModel> modules, Map<String, ModuleModel> map) {
    final levelMap = <String, int>{};

    int getLevel(String id, Set<String> visiting) {
      if (visiting.contains(id)) return 0; // cycle guard
      if (levelMap.containsKey(id)) return levelMap[id]!;
      final module = map[id];
      if (module == null || module.dependsOn.isEmpty) {
        levelMap[id] = 0;
        return 0;
      }
      visiting.add(id);
      final maxDep = module.dependsOn
          .map((depId) => getLevel(depId, Set.from(visiting)))
          .fold<int>(0, (a, b) => a > b ? a : b);
      visiting.remove(id);
      levelMap[id] = maxDep + 1;
      return maxDep + 1;
    }

    for (final m in modules) {
      getLevel(m.id, {});
    }

    final maxLevel = levelMap.values.fold<int>(0, (a, b) => a > b ? a : b);
    final levels = List.generate(maxLevel + 1, (_) => <ModuleModel>[]);
    for (final m in modules) {
      final l = levelMap[m.id] ?? 0;
      levels[l].add(m);
    }
    return levels;
  }
}

class _GraphNode extends StatelessWidget {
  final ModuleModel module;
  final VoidCallback onTap;
  const _GraphNode({required this.module, required this.onTap});

  Color get _statusColor => switch (module.status) {
    'complete'    => AppTheme.success,
    'in_progress' => AppTheme.warning,
    'review'      => AppTheme.purple,
    _             => AppTheme.textMuted,
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border(
            left: BorderSide(color: _statusColor, width: 3),
            top:  const BorderSide(color: AppTheme.border),
            right: const BorderSide(color: AppTheme.border),
            bottom: const BorderSide(color: AppTheme.border),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(module.name,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: (module.progress / 100).clamp(0.0, 1.0),
                backgroundColor: AppTheme.border,
                valueColor: AlwaysStoppedAnimation(_statusColor),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(module.status.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                    color: _statusColor, fontSize: 8, letterSpacing: 1.5,
                    fontFamily: 'Space Mono',
                  ),
                ),
                Text('${module.progress.toInt()}%',
                  style: TextStyle(
                    color: _statusColor, fontSize: 9,
                    fontWeight: FontWeight.w700, fontFamily: 'Space Mono',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      child: Row(
        children: [
          Expanded(
            child: Container(height: 1.5, color: AppTheme.border),
          ),
          const Icon(Icons.arrow_forward_ios_rounded,
            color: AppTheme.primary, size: 10),
        ],
      ),
    );
  }
}
