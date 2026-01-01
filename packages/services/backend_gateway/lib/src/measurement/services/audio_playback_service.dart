import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../../backend_http_client.dart';

// Conditional imports for file operations (native only)
import 'audio_playback_service_io.dart'
    if (dart.library.html) 'audio_playback_service_web.dart'
    as platform;

/// Service for playing measurement audio files.
///
/// This service is used by devices with the speaker role to play
/// the measurement audio signal.
class AudioPlaybackService {
  AudioPlaybackService();

  final AudioPlayer _player = AudioPlayer();
  final AudioPlayer _demoPlayer = AudioPlayer();
  String? _cachedAudioPath;
  Uint8List? _cachedAudioBytes;
  String? _audioUrl; // Store URL for web playback
  Completer<void>? _playbackCompleter;

  /// Whether audio is currently playing.
  bool get isPlaying => _player.state == PlayerState.playing;

  /// Stream of playback state changes.
  Stream<PlayerState> get onPlayerStateChanged => _player.onPlayerStateChanged;

  /// Stream of playback position changes.
  Stream<Duration> get onPositionChanged => _player.onPositionChanged;

  /// Stream of duration changes.
  Stream<Duration> get onDurationChanged => _player.onDurationChanged;

  /// Download the measurement audio from the backend.
  ///
  /// [httpClient] - The BackendHttpClient to use for the download
  /// [sessionId] - Optional session ID for tracking
  /// [sampleRate] - Sample rate in Hz (default: 48000)
  Future<String> downloadMeasurementAudio({
    required BackendHttpClient httpClient,
    String? sessionId,
    int sampleRate = 48000,
  }) async {
    final uri = httpClient.getMeasurementAudioUri(
      sessionId: sessionId,
      sampleRate: sampleRate,
    );

    debugPrint(
      '[AudioPlaybackService] Downloading measurement audio from: $uri',
    );

    if (kIsWeb) {
      // On web, store the URL and use it directly for playback
      // This is more reliable than using bytes on web
      _audioUrl = uri.toString();
      debugPrint(
        '[AudioPlaybackService] Running on web, will use URL directly: $_audioUrl',
      );
      return _audioUrl!;
    }

    // On native, download the file using BackendHttpClient
    final downloadedAudio = await httpClient.downloadMeasurementAudio(
      sessionId: sessionId,
      sampleRate: sampleRate,
    );

    debugPrint('[AudioPlaybackService] Audio Validation:');
    debugPrint('  File size: ${downloadedAudio.bytes.length} bytes');
    debugPrint('  Received Hash: ${downloadedAudio.receivedHash}');
    debugPrint('  Calculated Hash: ${downloadedAudio.calculatedHash}');
    debugPrint(
      '  Result: ${downloadedAudio.isHashValid ? "VALID" : "INVALID"}',
    );

    // Store audio bytes
    _cachedAudioBytes = downloadedAudio.bytes;

    // On native platforms, save to temporary file
    final filePath = await platform.saveAudioToFile(
      downloadedAudio.bytes,
      sessionId,
    );
    _cachedAudioPath = filePath;
    debugPrint('[AudioPlaybackService] Measurement audio saved to: $filePath');
    return filePath;
  }

  /// Prepare the audio player with the downloaded audio.
  Future<void> prepare({String? audioPath}) async {
    debugPrint('[AudioPlaybackService] prepare() called, kIsWeb=$kIsWeb');
    debugPrint('[AudioPlaybackService] _audioUrl: $_audioUrl');
    debugPrint(
      '[AudioPlaybackService] _cachedAudioBytes: ${_cachedAudioBytes?.length ?? 0} bytes',
    );
    debugPrint('[AudioPlaybackService] _cachedAudioPath: $_cachedAudioPath');

    // Set volume to max
    await _player.setVolume(1.0);
    debugPrint('[AudioPlaybackService] Volume set to 1.0');

    if (kIsWeb) {
      // On web, use URL source directly - this is the most reliable method
      if (_audioUrl == null) {
        throw StateError('No audio URL available. Download audio first.');
      }
      debugPrint('[AudioPlaybackService] Setting source from URL: $_audioUrl');
      await _player.setSourceUrl(_audioUrl!);
      await _player.setReleaseMode(ReleaseMode.stop);
      debugPrint('[AudioPlaybackService] Audio player prepared with URL (web)');
    } else {
      // On native platforms, use file
      final path = audioPath ?? _cachedAudioPath;
      if (path == null) {
        throw StateError('No audio path available. Download audio first.');
      }
      await _player.setSourceDeviceFile(path);
      await _player.setReleaseMode(ReleaseMode.stop);
      debugPrint('[AudioPlaybackService] Audio player prepared with: $path');
    }

    // Check duration
    final duration = await _player.getDuration();
    debugPrint('[AudioPlaybackService] Audio duration: $duration');
  }

  /// Play the bundled demo sample before the real measurement audio.
  Future<void> playDemoSample({String assetPath = 'audio/sample.wav'}) async {
    debugPrint('[AudioPlaybackService] playDemoSample() called');

    final completer = Completer<void>();
    late StreamSubscription<PlayerState> subscription;

    try {
      await _demoPlayer.stop();
      await _demoPlayer.setReleaseMode(ReleaseMode.stop);
      await _demoPlayer.setVolume(1.0);
      await _demoPlayer.setSourceAsset(assetPath);

      subscription = _demoPlayer.onPlayerStateChanged.listen((state) {
        debugPrint('[AudioPlaybackService] Demo player state: $state');
        if (state == PlayerState.completed || state == PlayerState.stopped) {
          if (!completer.isCompleted) {
            completer.complete();
          }
          subscription.cancel();
        }
      });

      await _demoPlayer.resume();
      await completer.future;
      debugPrint('[AudioPlaybackService] Demo playback finished');
    } catch (e, stackTrace) {
      debugPrint('[AudioPlaybackService] Demo playback failed: $e');
      debugPrint('[AudioPlaybackService] Stack trace: $stackTrace');
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  /// Play the measurement audio.
  ///
  /// Returns a Future that completes when playback is finished.
  Future<void> play() async {
    debugPrint('[AudioPlaybackService] play() called');
    debugPrint('[AudioPlaybackService] Current state: ${_player.state}');

    if (!kIsWeb && _cachedAudioPath == null) {
      throw StateError('No audio loaded. Call prepare() first.');
    }
    if (kIsWeb && _audioUrl == null) {
      throw StateError('No audio loaded. Call prepare() first.');
    }

    _playbackCompleter = Completer<void>();

    // Listen for playback state changes
    late StreamSubscription<PlayerState> subscription;
    subscription = _player.onPlayerStateChanged.listen((state) {
      debugPrint('[AudioPlaybackService] Player state changed: $state');
      if (state == PlayerState.completed || state == PlayerState.stopped) {
        if (!_playbackCompleter!.isCompleted) {
          _playbackCompleter!.complete();
        }
        subscription.cancel();
      }
    });

    // Also listen for errors
    _player.onLog.listen((log) {
      debugPrint('[AudioPlaybackService] Player log: $log');
    });

    debugPrint('[AudioPlaybackService] Calling resume()...');
    await _player.resume();
    debugPrint('[AudioPlaybackService] resume() completed');
    debugPrint('[AudioPlaybackService] State after resume: ${_player.state}');

    // Wait for playback to complete
    debugPrint('[AudioPlaybackService] Waiting for playback to complete...');
    await _playbackCompleter!.future;
    debugPrint('[AudioPlaybackService] Audio playback finished');
  }

  /// Stop playback immediately.
  Future<void> stop() async {
    await _player.stop();
    if (_playbackCompleter != null && !_playbackCompleter!.isCompleted) {
      _playbackCompleter!.complete();
    }
    debugPrint('[AudioPlaybackService] Audio playback stopped');
  }

  /// Pause playback.
  Future<void> pause() async {
    await _player.pause();
    debugPrint('[AudioPlaybackService] Audio playback paused');
  }

  /// Resume playback.
  Future<void> resume() async {
    await _player.resume();
    debugPrint('[AudioPlaybackService] Audio playback resumed');
  }

  /// Seek to a specific position.
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  /// Get the current playback position.
  Future<Duration?> getCurrentPosition() async {
    return _player.getCurrentPosition();
  }

  /// Get the total duration of the audio.
  Future<Duration?> getDuration() async {
    return _player.getDuration();
  }

  /// Set the playback volume (0.0 to 1.0).
  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume.clamp(0.0, 1.0));
  }

  /// Release resources.
  Future<void> dispose() async {
    await _player.dispose();
    await _demoPlayer.dispose();

    // Clear cached bytes and URL
    _cachedAudioBytes = null;
    _audioUrl = null;

    // Clean up cached file (native only)
    if (!kIsWeb && _cachedAudioPath != null) {
      await platform.deleteAudioFile(_cachedAudioPath!);
      _cachedAudioPath = null;
    }
  }
}
