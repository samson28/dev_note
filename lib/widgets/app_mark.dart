import 'package:flutter/widgets.dart';

/// The Dev Note logo.
///
/// Three places used to draw a plain accent square as a stand-in for it. This
/// is the real thing, from the asset the icon files are generated from, so the
/// window, the settings card and the notification-area icon are all the same
/// image.
///
/// It keeps its own colours rather than following the user's accent choice: a
/// logo that changes colour is not a logo.
class AppMark extends StatelessWidget {
  const AppMark({super.key, required this.size, this.radius});

  final double size;

  /// Corner rounding, when the mark is inset into a surface that needs it.
  /// The asset already carries the squircle, so this only clips it further.
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/icons/logo_256.png',
      width: size,
      height: size,
      // Downscaling a 256px asset to 15px in the title bar needs better than
      // the default nearest-neighbour or the caret turns to mush.
      filterQuality: FilterQuality.medium,
    );

    if (radius == null) return image;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius!),
      child: image,
    );
  }
}
