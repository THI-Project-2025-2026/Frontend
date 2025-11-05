part of 'landing_page_bloc.dart';

@immutable
sealed class LandingPageEvent {
  const LandingPageEvent();
}

/// Sets the currently highlighted feature card by index.
class LandingPageFeatureSelected extends LandingPageEvent {
  const LandingPageFeatureSelected(this.index);

  final int index;
}

/// Advances the feature carousel to the next item.
class LandingPageFeatureAdvanced extends LandingPageEvent {
  const LandingPageFeatureAdvanced({this.isAuto = false});

  final bool isAuto;
}

/// Toggles the expanded state of a FAQ entry.
class LandingPageFaqToggled extends LandingPageEvent {
  const LandingPageFaqToggled(this.index);

  final int index;
}

/// Starts or stops the demo audio preview player.
class LandingPageLivePreviewToggled extends LandingPageEvent {
  const LandingPageLivePreviewToggled();
}

/// Emits a synthetic submission result for the contact form.
class LandingPageContactSubmitted extends LandingPageEvent {
  const LandingPageContactSubmitted({
    required this.email,
    required this.message,
  });

  final String email;
  final String message;
}

/// Resets the contact form submission status to idle.
class LandingPageContactReset extends LandingPageEvent {
  const LandingPageContactReset();
}
