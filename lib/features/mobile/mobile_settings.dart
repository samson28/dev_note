import 'package:flutter/material.dart' show MaterialPageRoute, Scaffold;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_version.dart';
import '../../core/theme/jot_theme.dart';
import '../../state/settings_notifier.dart';
import '../../state/vault_notifier.dart';
import '../../widgets/app_mark.dart';
import '../../widgets/jot_icons.dart';
import '../../widgets/jot_primitives.dart';
import '../settings/widgets/settings_controls.dart';
import 'mobile_appearance.dart';
import 'mobile_subscreens.dart';
import 'mobile_trash.dart';

/// 4a — Réglages, racine.
///
/// The desktop window puts six tabs side by side; the phone turns the same
/// content into a stack of 48px rows that push a subscreen. Values sit on the
/// right of each row so the list reads as a summary, not just navigation.
class MobileSettingsScreen extends ConsumerWidget {
  const MobileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final vault = ref.watch(vaultProvider);

    return Scaffold(
      backgroundColor: JotColors.window,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MobileHeader(title: 'Réglages'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                children: [
                  _AppCard(noteCount: vault.totalNotes),
                  const SizedBox(height: 18),
                  MobileSection(
                    title: 'Application',
                    rows: [
                      MobileRow(
                        label: 'Général',
                        value: settings.defaultFolder,
                        onTap: () => _push(context, const MobileGeneralScreen()),
                      ),
                      MobileRow(
                        label: 'Apparence',
                        value: settings.theme.label,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const MobileAppearanceScreen(),
                          ),
                        ),
                      ),
                      MobileRow(
                        label: 'Capture rapide',
                        value: settings.captureFolder,
                        onTap: () => _push(context, const MobileCaptureScreen()),
                      ),
                      MobileRow(
                        label: 'Dossiers & tags',
                        value: '${vault.folders.length} · ${vault.tags.length}'
                            .replaceAll(' · ', ', '),
                        onTap: () => _push(context, const MobileFoldersScreen()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  MobileSection(
                    title: 'Données',
                    rows: [
                      MobileRow(
                        label: 'Stockage & sauvegarde',
                        onTap: () => _push(context, const MobileStorageScreen()),
                      ),
                      MobileRow(
                        label: 'Corbeille',
                        onTap: () => _push(context, const MobileTrashScreen()),
                      ),
                      MobileRow(
                        label: 'Masquer les #creds',
                        trailing: JotSwitch(
                          large: true,
                          value: settings.maskCredentialValues,
                          onChanged: (v) => notifier
                              .update((s) => s.copyWith(maskCredentialValues: v)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  MobileSection(
                    rows: [
                      MobileRow(
                        label: 'À propos',
                        value: AppVersion.name,
                        onTap: () => _push(context, const MobileAboutScreen()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'Aucune télémétrie, sync désactivée',
                      style: JotText.mono(
                        size: 11,
                        height: 1.5,
                        color: JotColors.textDisabled,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _push(BuildContext context, Widget screen) => Navigator.of(context)
    .push(MaterialPageRoute<void>(builder: (_) => screen));

/// Header shared by every mobile subscreen: a back affordance in the accent
/// colour, and the title centred when there is a parent to go back to.
class MobileHeader extends StatelessWidget {
  const MobileHeader({super.key, required this.title, this.parent});

  final String title;

  /// Name of the screen behind this one; shown beside the chevron.
  final String? parent;

  @override
  Widget build(BuildContext context) => Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: JotColors.borderSubtle)),
        ),
        child: Row(
          children: [
            Hoverable(
              onTap: () => Navigator.of(context).maybePop(),
              builder: (context, _) => Row(
                children: [
                  JotIcon(JotIcons.back, size: 18, color: JotColors.accent),
                  if (parent != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      parent!,
                      style: JotText.ui(size: 13, color: JotColors.accent),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Text(
                title,
                textAlign: parent == null ? TextAlign.left : TextAlign.center,
                style: JotText.ui(
                  size: parent == null ? 16 : 14,
                  weight: FontWeight.w600,
                  color: JotColors.textBright,
                ),
              ),
            ),
            // Balances the back affordance so a centred title stays centred.
            if (parent != null) SizedBox(width: 56 - parent!.length.toDouble()),
          ],
        ),
      );
}

/// A titled group of rows on the phone: 12px radius card, inset hairlines.
class MobileSection extends StatelessWidget {
  const MobileSection({super.key, required this.rows, this.title});

  final String? title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 9),
              child: SectionLabel(title!),
            ),
          ],
          Container(
            decoration: BoxDecoration(
              color: JotColors.editorSurface,
              border: Border.all(color: JotColors.borderWindow),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0)
                    Hairline(
                      color: JotColors.borderEditor,
                      inset: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                  rows[i],
                ],
              ],
            ),
          ),
        ],
      );
}

/// One 48px row: label, optional value, then a chevron or a control.
class MobileRow extends StatelessWidget {
  const MobileRow({
    super.key,
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
  });

  final String label;
  final String? value;

  /// A control replaces the chevron; a row with one is not itself tappable.
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: JotText.ui(size: 14, color: JotColors.textPrimary),
            ),
          ),
          if (value != null) ...[
            const SizedBox(width: 12),
            Text(
              value!,
              style: JotText.ui(size: 12.5, color: JotColors.textSubtle),
            ),
          ],
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ] else if (onTap != null) ...[
            const SizedBox(width: 8),
            JotIcon(JotIcons.forward, size: 16, color: JotColors.textDisabled),
          ],
        ],
      ),
    );

    return onTap == null
        ? row
        : Hoverable(onTap: onTap, builder: (context, _) => row);
  }
}

class _AppCard extends StatelessWidget {
  const _AppCard({required this.noteCount});

  final int noteCount;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: JotColors.editorSurface,
          border: Border.all(color: JotColors.borderWindow),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const AppMark(size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dev Note ${AppVersion.name}',
                    style: JotText.ui(
                      size: 14,
                      weight: FontWeight.w600,
                      color: JotColors.textBright,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$noteCount note${noteCount == 1 ? '' : 's'}, hors ligne',
                    style: JotText.mono(size: 11.5, color: JotColors.textFaint),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
