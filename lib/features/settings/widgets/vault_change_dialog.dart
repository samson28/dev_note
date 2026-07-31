import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/widgets.dart';

import '../../../core/theme/jot_theme.dart';
import '../../../widgets/jot_primitives.dart';

/// Asked once the user has picked a folder for the vault.
///
/// Two buttons because there are two genuinely different intents, and picking
/// one silently would be wrong half the time: someone pointing the app at a
/// folder their cloud client just restored wants it adopted untouched, while
/// someone moving the vault into a synced folder wants their notes carried
/// across. The dialog says what each will do to the files, in numbers.
class VaultChangeDialog extends StatelessWidget {
  const VaultChangeDialog({
    super.key,
    required this.target,
    required this.notesAlreadyThere,
  });

  final String target;

  /// How many `.md` files the chosen folder already holds.
  final int notesAlreadyThere;

  @override
  Widget build(BuildContext context) => Center(
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            width: 460,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            decoration: BoxDecoration(
              color: JotColors.raised,
              border: Border.all(color: JotColors.borderRaised),
              borderRadius: BorderRadius.circular(10),
              boxShadow: JotColors.active.shadow(JotMetrics.menuShadow),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Changer le dossier du coffre',
                  style: JotText.ui(
                    size: 14,
                    weight: FontWeight.w600,
                    color: JotColors.textBright,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: JotColors.codePanel,
                    border: Border.all(color: JotColors.borderRaised),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    target,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: JotText.mono(
                      size: 11.5,
                      height: 1.4,
                      color: JotColors.textDim,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  notesAlreadyThere == 0
                      ? 'Ce dossier est vide.'
                      : 'Ce dossier contient déjà $notesAlreadyThere note'
                          '${notesAlreadyThere == 1 ? '' : 's'}.',
                  style: JotText.ui(size: 12.5, height: 1.5, color: JotColors.textBody),
                ),
                const SizedBox(height: 4),
                Text(
                  'Déplacer copie vos notes actuelles ici, puis vide '
                  "l'ancien dossier, et seulement une fois la copie vérifiée. "
                  'Utiliser laisse les deux dossiers intacts et travaille '
                  'désormais dans celui-ci.',
                  style: JotText.ui(
                    size: 12,
                    height: 1.55,
                    color: JotColors.textSubtle,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    JotButton(
                      'Annuler',
                      kind: JotButtonKind.secondary,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    JotButton(
                      'Utiliser ce dossier',
                      kind: JotButtonKind.secondary,
                      onTap: () => Navigator.of(context).pop(false),
                    ),
                    const SizedBox(width: 8),
                    JotButton(
                      'Déplacer les notes',
                      onTap: () => Navigator.of(context).pop(true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}
