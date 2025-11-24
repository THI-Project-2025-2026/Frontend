import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:l10n_service/l10n_service.dart';

/// Signature for JavaScript handlers that can exchange messages with
/// `flutter_inappwebview`.
typedef SonalyzeJavaScriptHandler =
    FutureOr<dynamic> Function(
      InAppWebViewController controller,
      List<dynamic> arguments,
    );

/// Lightweight wrapper around `InAppWebView` that renders raw HTML/JS/CSS while
/// enforcing Sonalyze-specific defaults (e.g., Linux guardrails).
class SonalyzeWebView extends StatefulWidget {
  const SonalyzeWebView({
    super.key,
    required this.htmlContent,
    this.baseUrl,
    this.initialSettings,
    this.initialUserScripts = const <UserScript>[],
    this.javascriptHandlers = const <String, SonalyzeJavaScriptHandler>{},
    this.injectedAssets = const <String, String>{},
    this.initialJsonData,
    this.jsonDataVariableName = 'sonalyzeData',
    this.backgroundColor,
    this.onWebViewCreated,
    this.onLoadStop,
  });

  /// Full HTML document (can include inline JS + CSS) to render.
  final String htmlContent;

  /// Optional base URL used for resolving relative links/assets.
  final Uri? baseUrl;

  /// Custom settings forwarded to the underlying `InAppWebView`.
  final InAppWebViewSettings? initialSettings;

  /// User scripts injected before the page loads.
  final List<UserScript> initialUserScripts;

  /// Named JavaScript handlers exposed to the page that bridge to Dart.
  final Map<String, SonalyzeJavaScriptHandler> javascriptHandlers;

  /// Virtual assets to serve via interception.
  /// Keys are the file paths (e.g. "config.json") to match against the request URL.
  /// Values are the content of the file.
  final Map<String, String> injectedAssets;

  /// Optional JSON data to inject into the window object before the page loads.
  /// The data will be available as `window[jsonDataVariableName]`.
  final String? initialJsonData;

  /// The name of the global variable to store the JSON data in.
  /// Defaults to 'sonalyzeData'.
  final String jsonDataVariableName;

  /// Background color behind the page (transparent by default).
  final Color? backgroundColor;

  /// Hook invoked when the web view is created.
  final ValueChanged<InAppWebViewController>? onWebViewCreated;

  /// Hook invoked after a page finishes loading.
  final void Function(InAppWebViewController controller, Uri? url)? onLoadStop;

  @override
  State<SonalyzeWebView> createState() => _SonalyzeWebViewState();
}

class _SonalyzeWebViewState extends State<SonalyzeWebView> {
  InAppWebViewController? _controller;

  @override
  void didUpdateWidget(covariant SonalyzeWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controller = _controller;
    final shouldReload =
        widget.htmlContent != oldWidget.htmlContent ||
        widget.baseUrl != oldWidget.baseUrl;
    if (controller != null && shouldReload) {
      controller.loadData(
        data: widget.htmlContent,
        baseUrl: _baseWebUri,
        mimeType: 'text/html',
        encoding: 'utf-8',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLinuxDesktop()) {
      throw UnsupportedError(_unsupportedMessage);
    }

    final backgroundColor = widget.backgroundColor ?? _defaultBackgroundColor;
    final settings =
        widget.initialSettings ??
        InAppWebViewSettings(
          javaScriptEnabled: true,
          allowsInlineMediaPlayback: true,
          mediaPlaybackRequiresUserGesture: false,
          transparentBackground: _isTransparentBackground,
        );

    final userScripts = widget.initialUserScripts.toList();
    if (widget.initialJsonData != null) {
      userScripts.add(
        UserScript(
          source:
              'window.${widget.jsonDataVariableName} = ${widget.initialJsonData};',
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(color: backgroundColor),
      child: InAppWebView(
        initialSettings: settings,
        initialUserScripts: UnmodifiableListView(userScripts),
        initialData: InAppWebViewInitialData(
          data: widget.htmlContent,
          baseUrl: _baseWebUri,
          encoding: 'utf-8',
          mimeType: 'text/html',
        ),
        shouldInterceptRequest: widget.injectedAssets.isEmpty
            ? null
            : (controller, request) async {
                final url = request.url.toString();
                for (final entry in widget.injectedAssets.entries) {
                  if (url.endsWith(entry.key)) {
                    return WebResourceResponse(
                      contentType: 'application/json',
                      data: Uint8List.fromList(utf8.encode(entry.value)),
                    );
                  }
                }
                return null;
              },
        onWebViewCreated: (controller) {
          _controller = controller;
          widget.javascriptHandlers.forEach((name, handler) {
            controller.addJavaScriptHandler(
              handlerName: name,
              callback: (arguments) => handler(controller, arguments),
            );
          });
          widget.onWebViewCreated?.call(controller);
        },
        onLoadStop: widget.onLoadStop,
      ),
    );
  }

  @override
  void dispose() {
    _controller = null;
    super.dispose();
  }

  bool _isLinuxDesktop() {
    if (kIsWeb) {
      return false;
    }
    final resolvedPlatform =
        debugDefaultTargetPlatformOverride ?? defaultTargetPlatform;
    return resolvedPlatform == TargetPlatform.linux;
  }

  WebUri? get _baseWebUri {
    final uri = widget.baseUrl;
    if (uri == null) {
      return null;
    }
    return WebUri(uri.toString());
  }

  bool get _isTransparentBackground {
    final color = widget.backgroundColor ?? _defaultBackgroundColor;
    return color.a == 0;
  }

  Color get _defaultBackgroundColor {
    return AppConstants.getThemeColor('sonalyze_webview.background');
  }

  String get _unsupportedMessage {
    final translation = AppConstants.translation(
      'sonalyze_webview.unsupported',
    );
    if (translation is String && translation.isNotEmpty) {
      return translation;
    }
    return 'SonalyzeWebView is not supported on Linux targets.';
  }
}
