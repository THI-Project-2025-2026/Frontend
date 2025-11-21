part of 'landing_page_bloc.dart';

/// Submission lifecycle for the contact form CTA.
enum LandingPageSubmissionStatus { idle, submitting, success }

@immutable
class LandingPageState {
  LandingPageState({
    required List<LandingPageFeature> features,
    required List<LandingPageMetric> metrics,
    required List<LandingPageWorkflowStep> workflowSteps,
    required List<LandingPageFaqItem> faqItems,
    required this.activeFeatureIndex,
    required Set<int> expandedFaqs,
    required this.isLivePreviewPlaying,
    required this.submissionStatus,
    required this.lastInteraction,
  }) : features = UnmodifiableListView<LandingPageFeature>(features),
       metrics = UnmodifiableListView<LandingPageMetric>(metrics),
       workflowSteps = UnmodifiableListView<LandingPageWorkflowStep>(
         workflowSteps,
       ),
       faqItems = UnmodifiableListView<LandingPageFaqItem>(faqItems),
       expandedFaqs = Set<int>.unmodifiable(expandedFaqs);

  final UnmodifiableListView<LandingPageFeature> features;
  final UnmodifiableListView<LandingPageMetric> metrics;
  final UnmodifiableListView<LandingPageWorkflowStep> workflowSteps;
  final UnmodifiableListView<LandingPageFaqItem> faqItems;
  final int activeFeatureIndex;
  final Set<int> expandedFaqs;
  final bool isLivePreviewPlaying;
  final LandingPageSubmissionStatus submissionStatus;
  final DateTime lastInteraction;

  LandingPageFeature get activeFeature {
    if (features.isEmpty) {
      throw StateError(
        'LandingPageState.activeFeature accessed with empty list',
      );
    }
    final clampedIndex = activeFeatureIndex.clamp(0, features.length - 1);
    return features[clampedIndex];
  }

  LandingPageState copyWith({
    int? activeFeatureIndex,
    Set<int>? expandedFaqs,
    bool? isLivePreviewPlaying,
    LandingPageSubmissionStatus? submissionStatus,
    DateTime? lastInteraction,
  }) {
    return LandingPageState(
      features: features,
      metrics: metrics,
      workflowSteps: workflowSteps,
      faqItems: faqItems,
      activeFeatureIndex: activeFeatureIndex ?? this.activeFeatureIndex,
      expandedFaqs: expandedFaqs ?? this.expandedFaqs,
      isLivePreviewPlaying: isLivePreviewPlaying ?? this.isLivePreviewPlaying,
      submissionStatus: submissionStatus ?? this.submissionStatus,
      lastInteraction: lastInteraction ?? this.lastInteraction,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! LandingPageState) {
      return false;
    }
    return other.activeFeatureIndex == activeFeatureIndex &&
        _setsEqual(other.expandedFaqs, expandedFaqs) &&
        other.isLivePreviewPlaying == isLivePreviewPlaying &&
        other.submissionStatus == submissionStatus &&
        other.lastInteraction == lastInteraction &&
        identical(other.features, features) &&
        identical(other.metrics, metrics) &&
        identical(other.workflowSteps, workflowSteps) &&
        identical(other.faqItems, faqItems);
  }

  @override
  int get hashCode => Object.hash(
    activeFeatureIndex,
    Object.hashAllUnordered(expandedFaqs),
    isLivePreviewPlaying,
    submissionStatus,
    lastInteraction,
    features,
    metrics,
    workflowSteps,
    faqItems,
  );
  bool _setsEqual(Set<int> a, Set<int> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (final value in a) {
      if (!b.contains(value)) {
        return false;
      }
    }
    return true;
  }
}
