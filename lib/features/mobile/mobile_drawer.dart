import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/jot_theme.dart';
import '../../data/file_repository.dart';
import '../../state/vault_notifier.dart';
import '../../widgets/jot_icons.dart';
import '../../widgets/jot_primitives.dart';
import 'mobile_settings.dart';
import 'mobile_trash.dart';

/// 5a — the navigation drawer.
///
/// The design moved folders, tags and Réglages out of the bottom bar and into
/// a drawer opened from the header: "la barre du bas reste dédiée au contexte
/// et au bouton de capture". That keeps the one-thumb capture button
/// unobstructed, which is the whole point of the bottom bar.
class MobileDrawer extends ConsumerWidget {
  const MobileDrawer({super.key, required this.open, required this.onClose});

  /// Kept mounted while closed so it can animate out as well as in. Off-screen
  /// and inert in that state — a drawer that pops into place has no business
  /// carrying a shadow that promises depth.
  final bool open;
  final VoidCallback onClose;

  /// Short enough to stay out of the way, long enough to read as coming from
  /// the edge. `easeOutCubic` because the arrival is what the eye follows.
  static const _duration = Duration(milliseconds: 200);
  static const _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(vaultProvider);
    final width = MediaQuery.sizeOf(context).width * 0.82;

    return IgnorePointer(
      ignoring: !open,
      child: Stack(
      children: [
        Positioned.fill(
          child: AnimatedOpacity(
            opacity: open ? 1 : 0,
            duration: _duration,
            curve: _curve,
            child: GestureDetector(
              onTap: onClose,
              child: ColoredBox(color: JotColors.scrim),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: AnimatedSlide(
            // Retargets from wherever it currently sits, so a close during the
            // opening slide reverses rather than restarting.
            offset: open ? Offset.zero : const Offset(-1, 0),
            duration: _duration,
            curve: _curve,
            child: SizedBox(
            width: width,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: JotColors.chrome,
                boxShadow: JotColors.active.shadow(JotMetrics.drawerShadow),
              ),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Dev Note',
                              style: JotText.ui(
                                size: 19,
                                weight: FontWeight.w600,
                                color: JotColors.textBright,
                              ),
                            ),
                          ),
                          Hoverable(
                            onTap: onClose,
                            builder: (context, _) => JotIcon(
                              JotIcons.close,
                              size: 18,
                              color: JotColors.textDim,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(4, 4, 4, 8),
                            child: SectionLabel('Dossiers'),
                          ),
                          // The phone has no room for a chevron and no hover
                          // to reveal one, so the tree is always expanded and
                          // depth is carried by the indent alone.
                          for (final folder in state.folders)
                            _DrawerRow(
                              icon: JotIcons.folder,
                              label: FileRepository.leafOf(folder.name),
                              depth: FileRepository.depthOf(folder.name),
                              trailing: '${folder.noteCount}',
                              active: state.scope.isFolder(folder.name),
                              onTap: () {
                                ref
                                    .read(vaultProvider.notifier)
                                    .selectScope(FolderScope(folder.name));
                                onClose();
                              },
                            ),
                          _DrawerRow(
                            icon: JotIcons.trash,
                            label: 'Corbeille',
                            active: false,
                            onTap: () {
                              onClose();
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const MobileTrashScreen(),
                                ),
                              );
                            },
                          ),
                          if (state.tags.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.fromLTRB(4, 18, 4, 8),
                              child: SectionLabel('Tags'),
                            ),
                            for (final tag in state.tags)
                              _DrawerRow(
                                icon: JotIcons.tag,
                                label: tag.name,
                                trailing: '${tag.noteCount}',
                                active: state.scope.isTag(tag.name),
                                onTap: () {
                                  ref
                                      .read(vaultProvider.notifier)
                                      .selectScope(TagScope(tag.name));
                                  onClose();
                                },
                              ),
                          ],
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                    // Réglages sits at the foot of the drawer, per the design.
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: JotColors.borderSubtle),
                        ),
                      ),
                      child: _DrawerRow(
                        icon: JotIcons.settings,
                        label: 'Réglages',
                        active: false,
                        onTap: () {
                          onClose();
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const MobileSettingsScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ),
        ),
      ],
      ),
    );
  }
}

class _DrawerRow extends StatelessWidget {
  const _DrawerRow({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.trailing,
    this.depth = 0,
  });

  final IconData icon;
  final String label;
  final String? trailing;
  final int depth;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Hoverable(
        onTap: onTap,
        builder: (context, hovered) => Container(
          // 48px keeps every row above the 44px touch target the design asks
          // for.
          height: 48,
          padding: EdgeInsets.only(left: 12 + depth * 16.0, right: 12),
          decoration: BoxDecoration(
            color: active
                ? JotColors.accentWashSidebar
                : (hovered ? JotColors.neutralWash : null),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              JotIcon(
                icon,
                size: 16,
                color: active ? JotColors.accent : JotColors.textDim,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: JotText.ui(
                    size: 14,
                    weight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active ? JotColors.textBright : JotColors.textBody,
                  ),
                ),
              ),
              if (trailing != null)
                Text(
                  trailing!,
                  style: JotText.mono(
                    size: 12,
                    color: active ? JotColors.accent : JotColors.textSubtle,
                  ),
                ),
            ],
          ),
        ),
      );
}
