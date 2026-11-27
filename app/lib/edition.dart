/// Which version of the app this is.
///
/// The free Lite version is the same code built with
/// `--dart-define=SPIKESCORE_LITE=true` (see app/LITE.md). It has its own
/// Android app ID, so it installs next to the full version and never shares
/// its saved match.
///
/// Lite is for trying the app out: teams are just "Home" and "Away" with
/// shirt numbers, there are no signatures, locking or referee overrides, and
/// instead of the official scoresheet it shows a plain match summary.
class Edition {
  /// True when this build is SpikeScore Lite.
  static const bool lite = bool.fromEnvironment('SPIKESCORE_LITE');

  /// The app's name as shown on screen.
  static String appName(bool lite) => lite ? 'SpikeScore Lite' : 'SpikeScore';

  /// Where Lite's "Send feedback" and "Contact us" go. Leave blank and the
  /// app offers to copy the text instead of opening the email app.
  static const String contactEmail = '';
}
