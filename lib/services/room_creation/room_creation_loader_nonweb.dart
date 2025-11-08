import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

const _kAssetEntryPoint = 'assets/room_creator/index.html';
const _kChannelName = 'roomCreatorChannel';

enum RoomCreationThemeMode { light, dark }

typedef RoomCreationMessageCallback = void Function(String message);

class RoomCreationController {
  _RoomCreationViewState? _state;

  bool get isReady => _state?._isBridgeReady ?? false;

  Future<void> sendMessage(String message) async {
    final state = _state;
    if (state == null) {
      return;
    }
    await state._dispatchMessage(message);
  }

  Future<void> setThemeMode(RoomCreationThemeMode mode) async {
    final state = _state;
    if (state == null) {
      return;
    }
    await state._scheduleTheme(mode);
  }

  void _attach(_RoomCreationViewState state) {
    _state = state;
  }

  void _detach(_RoomCreationViewState state) {
    if (identical(_state, state)) {
      _state = null;
    }
  }
}

class RoomCreationView extends StatefulWidget {
  const RoomCreationView({
    super.key,
    this.controller,
    this.onMessage,
    required this.themeMode,
  });

  final RoomCreationController? controller;
  final RoomCreationMessageCallback? onMessage;
  final RoomCreationThemeMode themeMode;

  @override
  State<RoomCreationView> createState() => _RoomCreationViewState();
}

class _RoomCreationViewState extends State<RoomCreationView> {
  InAppWebViewController? _controller;
  final List<String> _pendingMessages = <String>[];
  RoomCreationThemeMode? _pendingTheme;
  bool _pageLoaded = false;
  bool _isBridgeReady = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
      throw UnimplementedError(
        'Room creation loader is not implemented for this platform.',
      );
    }
    widget.controller?._attach(this);
    _pendingTheme = widget.themeMode;
  }

  @override
  void didUpdateWidget(RoomCreationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    if (oldWidget.themeMode != widget.themeMode) {
      _pendingTheme = widget.themeMode;
      unawaited(_flushTheme());
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _controller = null;
    super.dispose();
  }

  Future<void> _flushTheme() async {
    if (_pendingTheme == null) {
      return;
    }
    await _scheduleTheme(_pendingTheme!);
  }

  Future<void> _scheduleTheme(RoomCreationThemeMode mode) async {
    _pendingTheme = mode;
    if (!_pageLoaded || !_isBridgeReady || _controller == null) {
      return;
    }
    final encoded = jsonEncode(mode.name);
    await _controller?.evaluateJavascript(
      source: 'window.roomCreator && window.roomCreator.setTheme($encoded);',
    );
    _pendingTheme = null;
  }

  Future<void> _dispatchMessage(String message) async {
    if (!_pageLoaded || _controller == null || !_isBridgeReady) {
      _pendingMessages.add(message);
      return;
    }
    await _controller?.evaluateJavascript(
      source:
          'window.roomCreator && window.roomCreator.receiveMessage(${jsonEncode(message)});',
    );
  }

  Future<void> _drainQueue() async {
    if (_pendingMessages.isEmpty || _controller == null || !_isBridgeReady) {
      return;
    }
    final toSend = List<String>.from(_pendingMessages);
    _pendingMessages.clear();
    for (final entry in toSend) {
      await _controller?.evaluateJavascript(
        source:
            'window.roomCreator && window.roomCreator.receiveMessage(${jsonEncode(entry)});',
      );
    }
  }

  void _handleIncomingMessage(dynamic payload) {
    final raw = payload?.toString() ?? '';
    if (raw == 'ready') {
      _isBridgeReady = true;
      unawaited(_scheduleTheme(_pendingTheme ?? widget.themeMode));
      unawaited(_drainQueue());
      return;
    }
    widget.onMessage?.call(raw);
  }

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialFile: _kAssetEntryPoint,
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        allowFileAccessFromFileURLs: true,
        allowUniversalAccessFromFileURLs: true,
        disableContextMenu: true,
      ),
      onWebViewCreated: (controller) {
        _controller = controller;
        controller.addJavaScriptHandler(
          handlerName: _kChannelName,
          callback: (arguments) {
            final message = arguments.isEmpty ? null : arguments.first;
            _handleIncomingMessage(message);
            return null;
          },
        );
      },
      onLoadStop: (controller, _) async {
        _pageLoaded = true;
        await _scheduleTheme(_pendingTheme ?? widget.themeMode);
        await _drainQueue();
      },
    );
  }
}
