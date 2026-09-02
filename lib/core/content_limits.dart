/// Size thresholds that decide when a note's body is treated as "large" and
/// gets the cheaper, safer rendering and editing paths instead of the normal
/// ones.
///
/// A 13,000-line JSON file froze the app on open: the JSON tree and the
/// syntax-highlighted code view each built one Flutter widget per line,
/// eagerly, for the whole document, and the live edit field held the entire
/// string in a single `TextField`. None of those scale to hundreds of
/// thousands of characters. Past this threshold, viewers default to a plain,
/// virtualised line list instead, and the richer views become an explicit,
/// one-tap choice rather than something that happens to every note that
/// happens to be large.
///
/// Measured in UTF-16 code units (`String.length`), which every Dart string
/// already carries at no extra cost, rather than in bytes: getting an exact
/// byte count needs an encode pass, and it is the two-orders-of-magnitude gap
/// between a normal note and a dumped API log this exists to catch, not the
/// last few percent.
abstract final class ContentLimits {
  /// About 150,000 characters, comfortably above a few thousand lines of
  /// ordinary JSON or code, comfortably below the 13,000-line file that
  /// prompted this. Shared by the JSON tree, the syntax-highlighted code
  /// view, the live edit field, and the "re-detect on every keystroke" check,
  /// so one number governs when a note counts as large everywhere.
  static const large = 150000;

  static bool isLarge(String content) => content.length > large;
}
