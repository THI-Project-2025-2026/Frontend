## Sonalyze WebView

`sonalyze_webview` is a reusable wrapper around [`flutter_inappwebview`](https://pub.dev/packages/flutter_inappwebview)
that lets any Sonalyze view render inline HTML/JS/CSS bundles while preserving
shared defaults (e.g., transparent backgrounds, inline media playback).

### Capabilities

- Render fully inlined HTML documents (including scripts/styles) via `InAppWebViewInitialData`.
- Provide an optional base URL so relative asset paths resolve correctly.
- Register named JavaScript handlers that call back into Dart.
- Customize settings/user scripts and react to `onWebViewCreated`/`onLoadStop` hooks.
- Throws an `UnsupportedError` on Linux as the upstream plugin does not ship a Linux implementation.

### Usage

```dart
import 'package:sonalyze_webview/sonalyze_webview.dart';

SonalyzeWebView(
	htmlContent: '<html><body><h1>Hello</h1></body></html>',
	baseUrl: Uri.parse('https://localhost/assets/'),
	javascriptHandlers: {
		'logMessage': (controller, args) {
			debugPrint('JS sent: $args');
		},
	},
	onLoadStop: (controller, url) => debugPrint('Loaded: $url'),
);
```

### Platform Notes

- Linux is intentionally unsupported and will throw to avoid undefined behavior.
- Android projects must keep `minSdkVersion >= 21` (already true for Sonalyze).
- iOS/macOS builds rely on WKWebView defaults—no extra Info.plist keys are needed today.
- When changing plugin settings, prefer supplying `initialSettings`/`initialUserScripts` via the widget constructor.

### Development

1. Update `pubspec.yaml` + `import_rules.yaml` whenever new dependencies are added.
2. Run `melos bootstrap`, `melos run lint:imports`, and `melos run test` before committing.
3. Keep implementation details under `lib/src/` and expose only `SonalyzeWebView` (plus helpers) through `lib/sonalyze_webview.dart`.
