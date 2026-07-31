import 'package:flutter/widgets.dart';

import '../../../core/theme/jot_theme.dart';
import '../../../widgets/jot_primitives.dart';

/// The building blocks every Réglages tab is assembled from.
///
/// The design uses one grammar throughout: an uppercase section label, then a
/// card on the sunken surface holding rows separated by inset hairlines. Each
/// row is a label (+ optional help line) on the left and one control on the
/// right. Keeping that in one place is what makes six tabs cheap to build and
/// impossible to drift apart.

/// `width:34px;height:19px;border-radius:10px` pill, accent when on.
class JotSwitch extends StatelessWidget {
  const JotSwitch({super.key, required this.value, required this.onChanged, this.large = false});

  final bool value;
  final ValueChanged<bool> onChanged;

  /// Mobile uses a 44×26 target instead of the desktop 34×19.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final width = large ? 44.0 : 34.0;
    final height = large ? 26.0 : 19.0;
    final knob = large ? 22.0 : 15.0;

    return Hoverable(
      onTap: () => onChanged(!value),
      builder: (context, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        width: width,
        height: height,
        padding: const EdgeInsets.all(2),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: value ? JotColors.accent : JotColors.borderTag,
          borderRadius: BorderRadius.circular(height / 2),
        ),
        child: Container(
          width: knob,
          height: knob,
          decoration: BoxDecoration(
            color: value ? JotColors.onAccent : JotColors.textFaint,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// Segmented control: a sunken trough with an accent fill on the selected
/// segment.
class JotSegmented<T> extends StatelessWidget {
  const JotSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.labelOf,
    this.mono = false,
    this.large = false,
  });

  final List<T> options;
  final T value;
  final ValueChanged<T> onChanged;
  final String Function(T)? labelOf;
  final bool mono;
  final bool large;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: JotColors.panel,
          border: Border.all(color: JotColors.borderWindow),
          borderRadius: BorderRadius.circular(large ? 8 : 6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in options) ...[
              if (option != options.first) const SizedBox(width: 2),
              Hoverable(
                onTap: () => onChanged(option),
                builder: (context, hovered) {
                  final selected = option == value;
                  return Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: mono ? 11 : 10,
                      vertical: large ? 7 : 6,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? JotColors.accent
                          : (hovered ? JotColors.neutralWash : null),
                      borderRadius: BorderRadius.circular(large ? 6 : 4),
                    ),
                    child: Text(
                      labelOf?.call(option) ?? '$option',
                      style: mono
                          ? JotText.mono(
                              size: large ? 12 : 11.5,
                              weight: selected ? FontWeight.w500 : FontWeight.w400,
                              color: selected ? JotColors.onAccent : JotColors.textMuted,
                            )
                          : JotText.ui(
                              size: large ? 12 : 11.5,
                              weight: selected ? FontWeight.w500 : FontWeight.w400,
                              color: selected ? JotColors.onAccent : JotColors.textMuted,
                            ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      );
}

/// Outlined dropdown affordance: `Inbox ▾`.
class JotSelect extends StatelessWidget {
  const JotSelect({
    super.key,
    required this.label,
    required this.onTap,
    this.mono = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool mono;

  @override
  Widget build(BuildContext context) => Hoverable(
        onTap: onTap,
        builder: (context, hovered) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(
              color: hovered ? JotColors.borderPaletteOuter : JotColors.borderRaised,
            ),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            '$label ▾',
            style: mono
                ? JotText.mono(size: 11.5, color: JotColors.textStrong)
                : JotText.ui(size: 11.5, color: JotColors.textStrong),
          ),
        ),
      );
}

/// Small outlined action button used inside setting rows ("Ouvrir",
/// "Reconstruire", "Vider"...).
class JotRowButton extends StatelessWidget {
  const JotRowButton({
    super.key,
    required this.label,
    required this.onTap,
    this.danger = false,
    this.mono = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool danger;
  final bool mono;

  @override
  Widget build(BuildContext context) => Hoverable(
        onTap: onTap,
        builder: (context, hovered) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: hovered
                ? (danger
                    ? JotColors.danger.withValues(alpha: 0.10)
                    : JotColors.neutralWash)
                : null,
            border: Border.all(
              color: danger ? JotColors.dangerBorder : JotColors.borderRaised,
            ),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            label,
            style: mono
                ? JotText.mono(
                    size: 11,
                    weight: FontWeight.w500,
                    color: danger ? JotColors.danger : JotColors.textStrong,
                  )
                : JotText.ui(
                    size: 11.5,
                    weight: FontWeight.w500,
                    color: danger ? JotColors.danger : JotColors.textStrong,
                  ),
          ),
        ),
      );
}

/// The design's slider: a 3px trough with an accent fill and a light knob.
class JotSlider extends StatelessWidget {
  const JotSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.width = 180,
    this.large = false,
  });

  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final double width;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final fraction = ((value - min) / (max - min)).clamp(0.0, 1.0);
    final trackHeight = large ? 4.0 : 3.0;
    final knob = large ? 20.0 : 13.0;

    return SizedBox(
      width: width,
      height: knob,
      child: LayoutBuilder(
        builder: (context, constraints) {
          void update(Offset local) {
            final ratio = (local.dx / constraints.maxWidth).clamp(0.0, 1.0);
            onChanged(min + ratio * (max - min));
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => update(d.localPosition),
            onHorizontalDragUpdate: (d) => update(d.localPosition),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: trackHeight,
                  decoration: BoxDecoration(
                    color: JotColors.borderTag,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(
                    height: trackHeight,
                    decoration: BoxDecoration(
                      color: JotColors.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Positioned(
                  left: (constraints.maxWidth - knob) * fraction,
                  child: Container(
                    width: knob,
                    height: knob,
                    decoration: BoxDecoration(
                      color: JotColors.textBright,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// One row inside a [SettingsCard]: label, optional help line, and a control.
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.label,
    this.help,
    this.helpWidget,
    this.helpIsError = false,
    this.trailing = const [],
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    this.labelWidget,
    this.highlighted = false,
    this.onTap,
  });

  final String label;
  final String? help;

  /// Overrides [help] when the help line needs mixed styling.
  final Widget? helpWidget;
  final bool helpIsError;

  /// Overrides [label] when the label needs mixed styling.
  final Widget? labelWidget;

  final List<Widget> trailing;
  final EdgeInsets padding;

  /// The Raccourcis tab tints the row currently capturing a combination.
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      color: highlighted ? JotColors.active.accentWash(0.07) : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                labelWidget ??
                    Text(
                      label,
                      style: JotText.ui(
                        size: 12.5,
                        weight: FontWeight.w500,
                        height: 1.3,
                        color: highlighted ? JotColors.textBright : JotColors.textPrimary,
                      ),
                    ),
                if (helpWidget != null) ...[
                  const SizedBox(height: 3),
                  helpWidget!,
                ] else if (help != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    help!,
                    style: JotText.ui(
                      size: 11.5,
                      height: 1.4,
                      color: helpIsError ? JotColors.danger : JotColors.textFaint,
                    ),
                  ),
                ],
              ],
            ),
          ),
          for (final widget in trailing) ...[
            const SizedBox(width: 14),
            widget,
          ],
        ],
      ),
    );

    return onTap == null
        ? content
        : Hoverable(onTap: onTap, builder: (context, _) => content);
  }
}

/// Card with inset hairlines between its rows.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children, this.danger = false});

  final List<Widget> children;

  /// The "Zone sensible" card uses a red-tinted border and dividers.
  final bool danger;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: JotColors.codePanel,
          border: Border.all(
            color: danger
                ? JotColors.danger.withValues(alpha: 0.28)
                : JotColors.borderEditor,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                Hairline(
                  color: danger
                      ? JotColors.danger.withValues(alpha: 0.18)
                      : JotColors.borderEditor,
                  inset: const EdgeInsets.symmetric(horizontal: 14),
                ),
              children[i],
            ],
          ],
        ),
      );
}

/// Uppercase label above a card.
class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.title, required this.child, this.gap = 10});

  final String title;
  final Widget child;
  final double gap;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(title),
          SizedBox(height: gap),
          child,
        ],
      );
}

/// The footer strip every tab ends with: a monospace status note on the left
/// and the actions on the right, above a hairline.
class SettingsFooter extends StatelessWidget {
  const SettingsFooter({super.key, required this.status, this.actions = const []});

  final String status;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: JotColors.borderEditor)),
        ),
        padding: const EdgeInsets.only(top: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                status,
                style: JotText.mono(size: 11, color: JotColors.textDisabled),
              ),
            ),
            for (final action in actions) ...[
              const SizedBox(width: 10),
              action,
            ],
          ],
        ),
      );
}

/// A keycap chip as drawn in the Raccourcis tab.
class ShortcutChip extends StatelessWidget {
  const ShortcutChip(this.label, {super.key, this.conflicting = false, this.capturing = false});

  final String label;
  final bool conflicting;
  final bool capturing;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: conflicting
              ? JotColors.danger.withValues(alpha: 0.10)
              : JotColors.raised,
          border: Border.all(
            color: conflicting
                ? JotColors.danger.withValues(alpha: 0.40)
                : JotColors.borderRaised,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: JotText.mono(
            size: 11,
            weight: FontWeight.w500,
            color: conflicting
                ? JotColors.danger
                : (capturing ? JotColors.accentHighlightText : JotColors.textStrong),
          ),
        ),
      );
}

/// One statistic tile from the Stockage tab.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: JotColors.codePanel,
          border: Border.all(color: JotColors.borderEditor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: JotText.ui(size: 10.5, tracking: 0.06, color: JotColors.textSubtle),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: JotText.mono(
                size: 20,
                weight: FontWeight.w500,
                color: JotColors.textBright,
              ),
            ),
          ],
        ),
      );
}
