import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'bloc/room_modeling_bloc.dart';
import 'tools_panel.dart';
import 'room_plan_canvas.dart';
import 'room_3d_preview.dart';
import 'room_modeling_l10n.dart';

class RoomModelingWidget extends StatelessWidget {
  const RoomModelingWidget({
    super.key,
    this.bloc,
    this.hideToolsPanel = false,
    this.readOnly = false,
  });

  /// Optional external bloc. If not provided, creates its own.
  final RoomModelingBloc? bloc;

  /// Whether to hide the tools panel and show only the canvas.
  final bool hideToolsPanel;

  /// When true, disables editing interactions (placing/moving/resizing) while
  /// still rendering the room model.
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    if (bloc != null) {
      return BlocProvider<RoomModelingBloc>.value(
        value: bloc!,
        child: RoomModelingView(
          hideToolsPanel: hideToolsPanel,
          readOnly: readOnly,
        ),
      );
    }
    return BlocProvider(
      create: (context) => RoomModelingBloc(),
      child:
          RoomModelingView(hideToolsPanel: hideToolsPanel, readOnly: readOnly),
    );
  }
}

class RoomModelingView extends StatefulWidget {
  const RoomModelingView({
    super.key,
    this.hideToolsPanel = false,
    this.readOnly = false,
  });

  final bool hideToolsPanel;
  final bool readOnly;

  @override
  State<RoomModelingView> createState() => _RoomModelingViewState();
}

class _RoomModelingViewState extends State<RoomModelingView> {
  static const double _minSideBySideWidth = 900;
  late final PageController _pageController;
  int _pageIndex = 1;

  @override
  void initState() {
    super.initState();
    _pageIndex = widget.hideToolsPanel ? 1 : 0;
    _pageController = PageController(initialPage: _pageIndex);
  }

  @override
  void didUpdateWidget(covariant RoomModelingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hideToolsPanel && _pageIndex != 1) {
      _setPage(1, animate: false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _setPage(int index, {bool animate = true}) {
    if (_pageIndex == index) {
      return;
    }
    setState(() => _pageIndex = index);
    if (!_pageController.hasClients) {
      return;
    }
    if (animate) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    } else {
      _pageController.jumpToPage(index);
    }
  }

  Widget _buildToggle(BuildContext context) {
    final activeColor = RoomModelingColors.color('preview.button_foreground');
    return ToggleButtons(
      isSelected: [_pageIndex == 0, _pageIndex == 1],
      onPressed: (index) => _setPage(index),
      constraints: const BoxConstraints(minHeight: 36, minWidth: 44),
      borderRadius: BorderRadius.circular(999),
      selectedColor: activeColor,
      color: activeColor.withValues(alpha: 0.6),
      fillColor: activeColor.withValues(alpha: 0.12),
      borderColor: Colors.transparent,
      selectedBorderColor: Colors.transparent,
      children: const [
        Tooltip(message: 'Tools', child: Icon(Icons.tune_outlined, size: 18)),
        Tooltip(
            message: 'Canvas', child: Icon(Icons.grid_on_outlined, size: 18)),
      ],
    );
  }

  Widget _buildToolsPanel({required bool showToggle}) {
    return SonalyzeSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showToggle)
            Align(
              alignment: Alignment.center,
              child: _buildToggle(context),
            ),
          if (showToggle) const SizedBox(height: 12),
          const Expanded(child: ToolsPanel()),
        ],
      ),
    );
  }

  Widget _buildCanvas({required bool showToggle}) {
    return SonalyzeSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showToggle)
            Align(
              alignment: Alignment.center,
              child: _buildToggle(context),
            ),
          if (showToggle) const SizedBox(height: 12),
          Expanded(
            child: Stack(
              children: [
                RoomPlanCanvas(enabled: !widget.readOnly),
                Positioned(
                  top: 16,
                  right: 16,
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: RoomModelingColors.color(
                      'preview.button_background',
                    ),
                    foregroundColor: RoomModelingColors.color(
                      'preview.button_foreground',
                    ),
                    tooltip: RoomModelingL10n.text('preview.tooltip'),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (dialogContext) => BlocProvider.value(
                          value: context.read<RoomModelingBloc>(),
                          child: Dialog(
                            backgroundColor: Colors.transparent,
                            insetPadding: const EdgeInsets.all(24),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                  maxWidth: 1200, maxHeight: 800),
                              child: const Room3DPreview(),
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Icon(Icons.view_in_ar),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _minSideBySideWidth;
        final showToggle = !isWide && !widget.hideToolsPanel;

        if (widget.hideToolsPanel) {
          return _buildCanvas(showToggle: false);
        }

        if (isWide) {
          return Row(
            children: [
              SizedBox(width: 250, child: _buildToolsPanel(showToggle: false)),
              const SizedBox(width: 16),
              Expanded(child: _buildCanvas(showToggle: false)),
            ],
          );
        }

        return PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildToolsPanel(showToggle: showToggle),
            _buildCanvas(showToggle: showToggle),
          ],
        );
      },
    );
  }
}
