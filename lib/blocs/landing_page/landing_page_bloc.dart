import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'landing_page_event.dart';
part 'landing_page_state.dart';

/// Bloc orchestrating interactive state for the landing page experience.
///
/// The bloc keeps track of which hero feature is highlighted, which FAQ
/// entries are expanded, whether the live preview is playing, and the status
/// of the contact form submission. All textual content and colors referenced
/// by the view live in the localization JSON files and theme JSON files
/// respectively.
class LandingPageBloc extends Bloc<LandingPageEvent, LandingPageState> {
  LandingPageBloc()
    : super(
        LandingPageState(
          features: LandingPageFeature.demoFeatures,
          metrics: LandingPageMetric.demoMetrics,
          workflowSteps: LandingPageWorkflowStep.demoSteps,
          faqItems: LandingPageFaqItem.demoFaqs,
          activeFeatureIndex: 0,
          expandedFaqs: const <int>{},
          isLivePreviewPlaying: false,
          submissionStatus: LandingPageSubmissionStatus.idle,
          lastInteraction: DateTime.now(),
        ),
      ) {
    on<LandingPageFeatureSelected>(_onFeatureSelected);
    on<LandingPageFeatureAdvanced>(_onFeatureAdvanced);
    on<LandingPageFaqToggled>(_onFaqToggled);
    on<LandingPageLivePreviewToggled>(_onLivePreviewToggled);
    on<LandingPageContactSubmitted>(_onContactSubmitted);
    on<LandingPageContactReset>(_onContactReset);

    _featureRotationTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => add(const LandingPageFeatureAdvanced(isAuto: true)),
    );
  }

  Timer? _featureRotationTimer;

  void _onFeatureSelected(
    LandingPageFeatureSelected event,
    Emitter<LandingPageState> emit,
  ) {
    if (state.features.isEmpty) {
      return;
    }
    final clampedIndex = event.index.clamp(0, state.features.length - 1);
    emit(
      state.copyWith(
        activeFeatureIndex: clampedIndex,
        lastInteraction: DateTime.now(),
      ),
    );
  }

  void _onFeatureAdvanced(
    LandingPageFeatureAdvanced event,
    Emitter<LandingPageState> emit,
  ) {
    if (state.features.isEmpty) {
      return;
    }

    final nextIndex = (state.activeFeatureIndex + 1) % state.features.length;
    emit(
      state.copyWith(
        activeFeatureIndex: nextIndex,
        lastInteraction: DateTime.now(),
      ),
    );
  }

  void _onFaqToggled(
    LandingPageFaqToggled event,
    Emitter<LandingPageState> emit,
  ) {
    final updated = Set<int>.from(state.expandedFaqs);
    if (updated.contains(event.index)) {
      updated.remove(event.index);
    } else {
      updated.add(event.index);
    }

    emit(state.copyWith(expandedFaqs: updated));
  }

  void _onLivePreviewToggled(
    LandingPageLivePreviewToggled event,
    Emitter<LandingPageState> emit,
  ) {
    emit(
      state.copyWith(
        isLivePreviewPlaying: !state.isLivePreviewPlaying,
        lastInteraction: DateTime.now(),
      ),
    );
  }

  Future<void> _onContactSubmitted(
    LandingPageContactSubmitted event,
    Emitter<LandingPageState> emit,
  ) async {
    emit(
      state.copyWith(
        submissionStatus: LandingPageSubmissionStatus.submitting,
        lastInteraction: DateTime.now(),
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 900));

    emit(state.copyWith(submissionStatus: LandingPageSubmissionStatus.success));
  }

  void _onContactReset(
    LandingPageContactReset event,
    Emitter<LandingPageState> emit,
  ) {
    emit(state.copyWith(submissionStatus: LandingPageSubmissionStatus.idle));
  }

  @override
  Future<void> close() {
    _featureRotationTimer?.cancel();
    return super.close();
  }
}

/// Metadata describing a hero feature highlight on the landing page.
class LandingPageFeature {
  const LandingPageFeature({
    required this.titleKey,
    required this.descriptionKey,
    required this.metricLabelKey,
    required this.metricValueKey,
    required this.gradientIndex,
    required this.icon,
  });

  final String titleKey;
  final String descriptionKey;
  final String metricLabelKey;
  final String metricValueKey;
  final int gradientIndex;
  final IconData icon;

  static const List<LandingPageFeature> demoFeatures = <LandingPageFeature>[
    LandingPageFeature(
      titleKey: 'landing_page.features.0.title',
      descriptionKey: 'landing_page.features.0.description',
      metricLabelKey: 'landing_page.features.0.metric_label',
      metricValueKey: 'landing_page.features.0.metric_value',
      gradientIndex: 0,
      icon: Icons.blur_linear,
    ),
    LandingPageFeature(
      titleKey: 'landing_page.features.1.title',
      descriptionKey: 'landing_page.features.1.description',
      metricLabelKey: 'landing_page.features.1.metric_label',
      metricValueKey: 'landing_page.features.1.metric_value',
      gradientIndex: 1,
      icon: Icons.graphic_eq,
    ),
    LandingPageFeature(
      titleKey: 'landing_page.features.2.title',
      descriptionKey: 'landing_page.features.2.description',
      metricLabelKey: 'landing_page.features.2.metric_label',
      metricValueKey: 'landing_page.features.2.metric_value',
      gradientIndex: 2,
      icon: Icons.auto_graph,
    ),
  ];
}

/// Summary metric tiles displayed below the hero section.
class LandingPageMetric {
  const LandingPageMetric({required this.labelKey, required this.valueKey});

  final String labelKey;
  final String valueKey;

  static const List<LandingPageMetric> demoMetrics = <LandingPageMetric>[
    LandingPageMetric(
      labelKey: 'landing_page.metrics.items.0.label',
      valueKey: 'landing_page.metrics.items.0.value',
    ),
    LandingPageMetric(
      labelKey: 'landing_page.metrics.items.1.label',
      valueKey: 'landing_page.metrics.items.1.value',
    ),
    LandingPageMetric(
      labelKey: 'landing_page.metrics.items.2.label',
      valueKey: 'landing_page.metrics.items.2.value',
    ),
  ];
}

/// Workflow step descriptors for the process timeline widget.
class LandingPageWorkflowStep {
  const LandingPageWorkflowStep({
    required this.titleKey,
    required this.descriptionKey,
    required this.index,
  });

  final String titleKey;
  final String descriptionKey;
  final int index;

  static const List<LandingPageWorkflowStep> demoSteps =
      <LandingPageWorkflowStep>[
        LandingPageWorkflowStep(
          index: 0,
          titleKey: 'landing_page.workflow.steps.0.title',
          descriptionKey: 'landing_page.workflow.steps.0.description',
        ),
        LandingPageWorkflowStep(
          index: 1,
          titleKey: 'landing_page.workflow.steps.1.title',
          descriptionKey: 'landing_page.workflow.steps.1.description',
        ),
        LandingPageWorkflowStep(
          index: 2,
          titleKey: 'landing_page.workflow.steps.2.title',
          descriptionKey: 'landing_page.workflow.steps.2.description',
        ),
      ];
}

/// FAQ entries displayed in the accordion widget.
class LandingPageFaqItem {
  const LandingPageFaqItem({
    required this.questionKey,
    required this.answerKey,
    required this.index,
  });

  final String questionKey;
  final String answerKey;
  final int index;

  static const List<LandingPageFaqItem> demoFaqs = <LandingPageFaqItem>[
    LandingPageFaqItem(
      index: 0,
      questionKey: 'landing_page.faq.items.0.question',
      answerKey: 'landing_page.faq.items.0.answer',
    ),
    LandingPageFaqItem(
      index: 1,
      questionKey: 'landing_page.faq.items.1.question',
      answerKey: 'landing_page.faq.items.1.answer',
    ),
    LandingPageFaqItem(
      index: 2,
      questionKey: 'landing_page.faq.items.2.question',
      answerKey: 'landing_page.faq.items.2.answer',
    ),
  ];
}
