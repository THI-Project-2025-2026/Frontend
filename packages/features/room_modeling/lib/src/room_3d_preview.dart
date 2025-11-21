import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:l10n_service/l10n_service.dart';
import 'package:sonalyze_webview/sonalyze_webview.dart';
import 'package:core_ui/core_ui.dart';

class Room3DPreview extends StatefulWidget {
  const Room3DPreview({super.key});

  @override
  State<Room3DPreview> createState() => _Room3DPreviewState();
}

class _Room3DPreviewState extends State<Room3DPreview> {
  static const _bundlePrefix = 'assets/frontend_roomcreator/';

  late final Future<String> _htmlFuture = _loadInlineBundle();

  @override
  Widget build(BuildContext context) {
    final panelColor =
        AppConstants.getThemeColor('simulation_page.panel_background');
    final title = _translationOrFallback(
      'simulation_page.room_creator.title',
      'Interactive Room Creator',
    );
    final description = _translationOrFallback(
      'simulation_page.room_creator.subtitle',
      'Experiment with a fully interactive layout preview.',
    );

    if (_isLinuxDesktop) {
      return _RoomCreatorNotice(
        title: title,
        description: description,
        message: _translationOrFallback(
          'simulation_page.room_creator.unsupported',
          'This preview is unavailable on Linux builds.',
        ),
        panelColor: panelColor,
        wrapInSurface: true,
      );
    }

    return SonalyzeSurface(
      padding: const EdgeInsets.all(28),
      backgroundColor: panelColor.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.75),
                        ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: FutureBuilder<String>(
                future: _htmlFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const _RoomCreatorLoading();
                  }
                  if (snapshot.hasError) {
                    return _RoomCreatorNotice(
                      title: title,
                      description: description,
                      message: _translationOrFallback(
                        'simulation_page.room_creator.error',
                        'Unable to load the Room Creator bundle.',
                      ),
                      panelColor: panelColor,
                      wrapInSurface: false,
                    );
                  }
                  final html = snapshot.data ?? '';
                  if (html.isEmpty) {
                    return _RoomCreatorNotice(
                      title: title,
                      description: description,
                      message: _translationOrFallback(
                        'simulation_page.room_creator.empty',
                        'No web content available.',
                      ),
                      panelColor: panelColor,
                      wrapInSurface: false,
                    );
                  }
                  return SonalyzeWebView(
                    htmlContent: html,
                    backgroundColor: Colors.black,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _isLinuxDesktop {
    if (kIsWeb) {
      return false;
    }
    final resolved =
        debugDefaultTargetPlatformOverride ?? defaultTargetPlatform;
    return resolved == TargetPlatform.linux;
  }

  Future<String> _loadInlineBundle() async {
    var html = await rootBundle.loadString('${_bundlePrefix}index.html');
    html = await _inlineStyles(html);
    html = await _inlineScripts(html);
    html = await _inlineFavicon(html);
    html = _stripNoscript(html);
    return html;
  }

  Future<String> _inlineStyles(String html) async {
    final regex = RegExp(
      r'<link[^>]*rel=["\"][^>]*stylesheet[^>]*href=["\"]([^"\"]+)["\"][^>]*>',
      caseSensitive: false,
    );
    final matches = regex.allMatches(html).toList();
    for (final match in matches) {
      final tag = match.group(0)!;
      final fileName = match.group(1)!;
      final css = await rootBundle.loadString('$_bundlePrefix$fileName');
      html = html.replaceFirst(tag, '<style>$css</style>');
    }
    return html;
  }

  Future<String> _inlineScripts(String html) async {
    final regex = RegExp(
      r'<script[^>]*src=["\"]([^"\"]+)["\"][^>]*></script>',
      caseSensitive: false,
    );
    final matches = regex.allMatches(html).toList();
    for (final match in matches) {
      final tag = match.group(0)!;
      final fileName = match.group(1)!;
      final js = await rootBundle.loadString('$_bundlePrefix$fileName');
      final typeMatch = RegExp(r'type=["\"]([^"\"]+)["\"]').firstMatch(tag);
      final typeAttr = typeMatch != null ? ' type="${typeMatch.group(1)}"' : '';
      html = html.replaceFirst(tag, '<script$typeAttr>$js</script>');
    }
    return html;
  }

  Future<String> _inlineFavicon(String html) async {
    final regex = RegExp(
      r'<link[^>]*rel=["\"]icon["\"][^>]*href=["\"]([^"\"]+)["\"][^>]*>',
      caseSensitive: false,
    );
    final match = regex.firstMatch(html);
    if (match == null) {
      return html;
    }
    final tag = match.group(0)!;
    final fileName = match.group(1)!;
    final data = await rootBundle.load('$_bundlePrefix$fileName');
    final bytes = data.buffer.asUint8List();
    final dataUri = 'data:image/x-icon;base64,${base64Encode(bytes)}';
    final replacement = tag.replaceFirst(fileName, dataUri);
    return html.replaceFirst(tag, replacement);
  }

  String _stripNoscript(String html) {
    return html.replaceAll(
      RegExp(r'<noscript>.*?</noscript>', dotAll: true),
      '',
    );
  }

  String _translationOrFallback(String key, String fallback) {
    final translation = AppConstants.translation(key);
    if (translation is String && translation.isNotEmpty) {
      return translation;
    }
    return fallback;
  }
}

class _RoomCreatorNotice extends StatelessWidget {
  const _RoomCreatorNotice({
    required this.title,
    required this.description,
    required this.message,
    required this.panelColor,
    this.wrapInSurface = false,
  });

  final String title;
  final String description;
  final String message;
  final Color panelColor;
  final bool wrapInSurface;

  @override
  Widget build(BuildContext context) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(
          description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
        ),
        const SizedBox(height: 16),
        Text(
          message,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );

    if (!wrapInSurface) {
      return Center(child: body);
    }

    return SonalyzeSurface(
      padding: const EdgeInsets.all(28),
      backgroundColor: panelColor.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(28),
      child: body,
    );
  }
}

class _RoomCreatorLoading extends StatelessWidget {
  const _RoomCreatorLoading();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}
