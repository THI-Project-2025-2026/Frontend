import 'dart:convert';
import 'dart:io';

const _colorReset = '\u001b[0m';
const _colorGreen = '\u001b[32m';
const _colorRed = '\u001b[31m';
const _colorYellow = '\u001b[33m';
const _colorCyan = '\u001b[36m';

Future<void> main() async {
  final packages = await _collectPackages();
  if (packages.isEmpty) {
    stderr.writeln('No packages found for analysis.');
    exit(1);
  }

  final results = <_AnalysisResult>[];
  for (final pkg in packages) {
    final result = await _runAnalysis(pkg);
    results.add(result);
  }

  _printSummary(results);

  final totalIssues = results.fold<int>(0, (sum, r) => sum + r.issueCount);
  exit(totalIssues == 0 ? 0 : 1);
}

Future<List<_PackageTarget>> _collectPackages() async {
  final targets = <_PackageTarget>[];
  final rootPubspec = File('pubspec.yaml');
  if (await rootPubspec.exists()) {
    targets.add(await _PackageTarget.fromPubspec(rootPubspec, '.'));
  }

  final packagesDir = Directory('packages');
  if (await packagesDir.exists()) {
    final queue = <Directory>[packagesDir];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      final pubspec = File('${current.path}/pubspec.yaml');
      if (pubspec.existsSync()) {
        targets.add(await _PackageTarget.fromPubspec(pubspec, current.path));
        continue;
      }

      for (final entity in current.listSync()) {
        if (entity is Directory &&
            !entity.path.split(Platform.pathSeparator).last.startsWith('.')) {
          queue.add(entity);
        }
      }
    }
  }

  return targets;
}

Future<_AnalysisResult> _runAnalysis(_PackageTarget target) async {
  stdout.writeln('Analyzing ${target.name}:');

  final result = await Process.run(
    'flutter',
    ['analyze', '--no-pub'],
    workingDirectory: target.path,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );

  final combinedOutput = StringBuffer()
    ..write(result.stdout ?? '')
    ..write(result.stderr ?? '');

  final issues = _parseIssues(combinedOutput.toString());
  final issueCount = issues.length;
  final resultLabel = issueCount == 0
      ? '$_colorGreen[OK]$_colorReset'
      : '$_colorRed[ISSUES]$_colorReset';
  stdout.writeln('$resultLabel Found $issueCount issues');

  for (final issue in issues) {
    final coloredType =
        '${_colorizeIssueType(issue.type)}${issue.type.toUpperCase()}$_colorReset';
    stdout.writeln('$coloredType: ${issue.message} in ${issue.location}');
  }

  if (issueCount == 0 &&
      !combinedOutput.toString().contains('No issues found!')) {
    // Analyzer succeeded but did not emit the standard "No issues found" line; surface raw output for context.
    final output = combinedOutput.toString().trim();
    if (output.isNotEmpty) {
      stdout.writeln(output);
    }
  }

  if (issueCount > 0 && result.exitCode == 0) {
    // Preserve non-zero exit to signal CI failures.
    return _AnalysisResult(target.name, issueCount, 1);
  }

  return _AnalysisResult(target.name, issueCount, result.exitCode);
}

List<_AnalyzerIssue> _parseIssues(String output) {
  final issues = <_AnalyzerIssue>[];
  final regex = RegExp(
    r'^\s*(info|warning|error)\s•\s(.+?)\s•\s(.+?:\d+:\d+)\s•',
    multiLine: true,
  );

  for (final match in regex.allMatches(output)) {
    issues.add(
      _AnalyzerIssue(
        type: match.group(1) ?? 'info',
        message: match.group(2)?.trim() ?? '',
        location: match.group(3)?.trim() ?? '',
      ),
    );
  }

  return issues;
}

String _colorizeIssueType(String type) {
  switch (type) {
    case 'error':
      return _colorRed;
    case 'warning':
      return _colorYellow;
    case 'info':
    default:
      return _colorCyan;
  }
}

void _printSummary(List<_AnalysisResult> results) {
  stdout.writeln('\nSummary');
  const headerPackage = 'Package';
  const headerIssues = 'Issues';
  final nameWidth = results
      .map((r) => r.packageName.length)
      .fold<int>(headerPackage.length, (max, len) => len > max ? len : max);
  final separator =
      '+${'-' * (nameWidth + 2)}+${'-' * (headerIssues.length + 2)}+';

  stdout.writeln(separator);
  stdout.writeln('| ${headerPackage.padRight(nameWidth)} | $headerIssues |');
  stdout.writeln(separator);
  for (final result in results) {
    final issuesText = result.issueCount.toString().padLeft(
      headerIssues.length,
    );
    stdout.writeln(
      '| ${result.packageName.padRight(nameWidth)} | $issuesText |',
    );
  }
  stdout.writeln(separator);
}

class _PackageTarget {
  _PackageTarget(this.name, this.path);

  final String name;
  final String path;

  static Future<_PackageTarget> fromPubspec(File pubspec, String path) async {
    final name = await _extractPackageName(pubspec);
    return _PackageTarget(name, path);
  }
}

Future<String> _extractPackageName(File pubspec) async {
  final lines = await pubspec.readAsLines();
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.startsWith('name:')) {
      return trimmed
          .substring('name:'.length)
          .trim()
          .replaceAll("'", '')
          .replaceAll('"', '');
    }
  }
  throw StateError('Could not determine package name from ${pubspec.path}');
}

class _AnalyzerIssue {
  _AnalyzerIssue({
    required this.type,
    required this.message,
    required this.location,
  });

  final String type;
  final String message;
  final String location;
}

class _AnalysisResult {
  _AnalysisResult(this.packageName, this.issueCount, this.exitCode);

  final String packageName;
  final int issueCount;
  final int exitCode;
}
