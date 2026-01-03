/// Predefined measurement profiles for different hardware capabilities.
///
/// Each profile defines the frequency range used for the measurement sweep,
/// optimized for specific hardware types.
enum MeasurementProfile {
  /// High-end measurement profile.
  ///
  /// Uses the full audible frequency range (20 Hz - 20 kHz).
  /// Suitable for professional audio equipment with full-range speakers
  /// and high-quality microphones.
  highEnd(
    id: 'high_end',
    labelKey: 'measurement_page.profile.high_end',
    descriptionKey: 'measurement_page.profile.high_end_description',
    sweepFStart: 20.0,
    sweepFEnd: 20000.0,
  ),

  /// Smartphone-optimized measurement profile.
  ///
  /// Uses a limited frequency range (400 Hz - 10 kHz) that smartphone
  /// speakers can reliably produce and smartphone microphones can accurately
  /// record. This avoids frequencies where phone hardware typically has
  /// significant distortion or roll-off.
  smartphone(
    id: 'smartphone',
    labelKey: 'measurement_page.profile.smartphone',
    descriptionKey: 'measurement_page.profile.smartphone_description',
    sweepFStart: 400.0,
    sweepFEnd: 10000.0,
  );

  const MeasurementProfile({
    required this.id,
    required this.labelKey,
    required this.descriptionKey,
    required this.sweepFStart,
    required this.sweepFEnd,
  });

  /// Unique identifier for the profile.
  final String id;

  /// Localization key for the profile display name.
  final String labelKey;

  /// Localization key for the profile description.
  final String descriptionKey;

  /// Start frequency of the measurement sweep in Hz.
  final double sweepFStart;

  /// End frequency of the measurement sweep in Hz.
  final double sweepFEnd;

  /// Fallback label for when localization is not available.
  String get fallbackLabel => switch (this) {
    MeasurementProfile.highEnd => 'High-End (20 Hz - 20 kHz)',
    MeasurementProfile.smartphone => 'Smartphone (400 Hz - 10 kHz)',
  };

  /// Fallback description for when localization is not available.
  String get fallbackDescription => switch (this) {
    MeasurementProfile.highEnd =>
      'Full frequency range for professional equipment',
    MeasurementProfile.smartphone =>
      'Optimized range for smartphone speakers and microphones',
  };
}
