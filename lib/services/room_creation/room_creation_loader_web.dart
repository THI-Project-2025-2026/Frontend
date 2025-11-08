// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

const _kAssetEntryPoint = 'assets/room_creator/index.html';
const _kBridgeContext = 'roomCreatorBridge';

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
  static int _viewCounter = 0;

  late final String _viewType;
  html.IFrameElement? _iframe;
  StreamSubscription<html.Event>? _loadSubscription;
  StreamSubscription<html.MessageEvent>? _messageSubscription;
  final List<String> _pendingMessages = <String>[];
  RoomCreationThemeMode? _pendingTheme;
  bool _isBridgeReady = false;

  @override
  void initState() {
    super.initState();
    _viewCounter += 1;
    _viewType = 'room-creation-view-$_viewCounter';
    _pendingTheme = widget.themeMode;
    widget.controller?._attach(this);
    _registerViewFactory();
    _messageSubscription = html.window.onMessage.listen(_handleWindowMessage);
  }

  void _registerViewFactory() {
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final element = html.IFrameElement()
        ..src = _resolveAssetUrl(_kAssetEntryPoint)
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = 'transparent'
        ..setAttribute('sandbox', 'allow-scripts allow-same-origin');
      _iframe = element;
      _loadSubscription = element.onLoad.listen((_) {
        // The iframe finished loading the initial document.
        _post(<String, dynamic>{
          'context': _kBridgeContext,
          'type': 'bootstrap',
        });
      });
      return element;
    });
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
      unawaited(_syncTheme());
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _messageSubscription?.cancel();
    _loadSubscription?.cancel();
    _iframe = null;
    super.dispose();
  }

  Future<void> _dispatchMessage(String message) async {
    if (!_isBridgeReady || _iframe?.contentWindow == null) {
      _pendingMessages.add(message);
      return;
    }
    _post(<String, dynamic>{
      'context': _kBridgeContext,
      'type': 'message',
      'value': message,
    });
  }

  Future<void> _scheduleTheme(RoomCreationThemeMode mode) async {
    _pendingTheme = mode;
    await _syncTheme();
  }

  Future<void> _syncTheme() async {
    if (_pendingTheme == null ||
        !_isBridgeReady ||
        _iframe?.contentWindow == null) {
      return;
    }
    final mode = _pendingTheme!;
    _post(<String, dynamic>{
      'context': _kBridgeContext,
      'type': 'setTheme',
      'value': mode.name,
    });
    _pendingTheme = null;
  }

  Future<void> _drainQueue() async {
    if (_pendingMessages.isEmpty ||
        !_isBridgeReady ||
        _iframe?.contentWindow == null) {
      return;
    }
    final messages = List<String>.from(_pendingMessages);
    _pendingMessages.clear();
    for (final entry in messages) {
      _post(<String, dynamic>{
        'context': _kBridgeContext,
        'type': 'message',
        'value': entry,
      });
    }
  }

  void _handleWindowMessage(html.MessageEvent event) {
    final data = event.data;
    String? raw;
    if (data is String) {
      raw = data;
    } else if (data != null) {
      raw = data.toString();
    }
    if (raw == null || raw.isEmpty) {
      return;
    }

    Map<String, dynamic>? payload;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        payload = decoded;
      }
    } catch (_) {
      return;
    }

    if (payload == null || payload['context'] != _kBridgeContext) {
      return;
    }

    final type = payload['type']?.toString();
    switch (type) {
      case 'ready':
        _isBridgeReady = true;
        unawaited(_syncTheme());
        unawaited(_drainQueue());
        break;
      case 'message':
        final value = payload['value']?.toString() ?? '';
        widget.onMessage?.call(value);
        break;
    }
  }

  void _post(Map<String, dynamic> payload) {
    final message = jsonEncode(payload);
    _iframe?.contentWindow?.postMessage(message, '*');
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}

String _resolveAssetUrl(String assetPath) {
  // Flutter serves web assets relative to the base href; keep the raw path.
  return assetPath;
}
