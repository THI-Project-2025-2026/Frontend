import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonalyze_webview/sonalyze_webview.dart';

void main() {
  testWidgets('throws UnsupportedError on Linux', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;

    await tester.pumpWidget(
      const MaterialApp(home: SonalyzeWebView(htmlContent: '<h1>Test</h1>')),
    );

    final dynamic exception = tester.takeException();
    expect(exception, isA<UnsupportedError>());
    debugDefaultTargetPlatformOverride = null;
  });
}
