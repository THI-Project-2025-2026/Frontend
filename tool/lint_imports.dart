import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

void main() {
  final workspacePackages = _discoverWorkspacePackages();
  final rules = _loadRules(workspacePackages);
  final workspaceNames = workspacePackages.keys.toSet();

  final violations = <_ImportViolation>[];

  for (final rule in rules.values) {
    final libDir = Directory(p.normalize(p.join(rule.path, 'lib')));
    if (!libDir.existsSync()) {
      stderr.writeln(
        'Warning: ${rule.name} has no lib directory at ${libDir.path}',
      );
      continue;
    }

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }

      final content = entity.readAsStringSync();
      for (final match in _importPattern.allMatches(content)) {
        final importedPackage = match.group(1);
        if (importedPackage == null || importedPackage == rule.name) {
          continue;
        }

        if (!workspaceNames.contains(importedPackage)) {
          continue; // External package imports are allowed.
        }

        if (rule.allowedPackages.contains(importedPackage)) {
          continue;
        }

        final location = _offsetToLineColumn(content, match.start);
        final relativeFilePath = p.relative(
          entity.path,
          from: Directory.current.path,
        );
        violations.add(
          _ImportViolation(
            sourcePackage: rule.name,
            targetPackage: importedPackage,
            filePath: relativeFilePath,
            line: location.line,
            column: location.column,
          ),
        );
      }
    }
  }

  if (violations.isEmpty) {
    stdout.writeln('All workspace imports comply with import_rules.yaml.');
    return;
  }

  violations.sort((a, b) {
    final fileCompare = a.filePath.compareTo(b.filePath);
    if (fileCompare != 0) {
      return fileCompare;
    }
    final lineCompare = a.line.compareTo(b.line);
    if (lineCompare != 0) {
      return lineCompare;
    }
    return a.column.compareTo(b.column);
  });

  stderr.writeln('Detected ${violations.length} invalid workspace import(s):');
  for (final violation in violations) {
    stderr.writeln(
      ' - ${violation.sourcePackage} imports disallowed package '
      '${violation.targetPackage} in ${violation.filePath}:${violation.line}:${violation.column}',
    );
  }
  exit(1);
}

final RegExp _importPattern = RegExp(
  r'''(?:import|export)\s+['"]package:([^/'"]+)[^'"]*['"]''',
);

Map<String, _PackageRule> _loadRules(
  Map<String, _WorkspacePackage> workspacePackages,
) {
  final configFile = File('import_rules.yaml');
  if (!configFile.existsSync()) {
    stderr.writeln('Missing import_rules.yaml in repository root.');
    exit(1);
  }

  final rawConfig = loadYaml(configFile.readAsStringSync());
  if (rawConfig is! YamlMap || rawConfig['packages'] is! YamlMap) {
    stderr.writeln('import_rules.yaml must define a top-level "packages" map.');
    exit(1);
  }

  final packagesNode = rawConfig['packages'] as YamlMap;
  final rules = <String, _PackageRule>{};

  for (final entry in packagesNode.entries) {
    final name = entry.key?.toString();
    final value = entry.value;
    if (name == null || value is! YamlMap) {
      stderr.writeln(
        'Each entry under "packages" must map to a config object.',
      );
      exit(1);
    }

    final pathValue = value['path'];
    if (pathValue == null) {
      stderr.writeln(
        'Package "$name" is missing a "path" in import_rules.yaml.',
      );
      exit(1);
    }

    final allowedNode = value['allowed_packages'];
    final allowedPackages = <String>{};
    if (allowedNode is YamlList) {
      for (final pkg in allowedNode) {
        if (pkg == null) {
          continue;
        }
        allowedPackages.add(pkg.toString());
      }
    } else if (allowedNode != null) {
      stderr.writeln(
        'Package "$name" has an invalid "allowed_packages" entry. Expect a list of package names.',
      );
      exit(1);
    }

    if (!workspacePackages.containsKey(name)) {
      stderr.writeln(
        'Package "$name" in import_rules.yaml is not part of the workspace.',
      );
      exit(1);
    }

    rules[name] = _PackageRule(
      name: name,
      path: pathValue.toString(),
      allowedPackages: allowedPackages,
    );
  }

  final missingPackages = workspacePackages.keys
      .where((name) => !rules.containsKey(name))
      .toList();
  if (missingPackages.isNotEmpty) {
    stderr.writeln(
      'Missing package entries in import_rules.yaml: ${missingPackages.join(', ')}',
    );
    exit(1);
  }

  return rules;
}

Map<String, _WorkspacePackage> _discoverWorkspacePackages() {
  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('pubspec.yaml not found in repository root.');
    exit(1);
  }

  final doc = loadYaml(pubspec.readAsStringSync());
  if (doc is! YamlMap) {
    stderr.writeln('Unable to parse pubspec.yaml.');
    exit(1);
  }

  final packages = <String, _WorkspacePackage>{};

  final rootName = doc['name']?.toString();
  if (rootName == null) {
    stderr.writeln('Root pubspec.yaml does not declare a package name.');
    exit(1);
  }
  packages[rootName] = _WorkspacePackage(name: rootName, path: '.');

  final workspaceNode = doc['workspace'];
  if (workspaceNode is YamlList) {
    for (final entry in workspaceNode) {
      if (entry == null) {
        continue;
      }
      final relativePath = entry.toString();
      final packagePubspec = File(p.join(relativePath, 'pubspec.yaml'));
      if (!packagePubspec.existsSync()) {
        stderr.writeln(
          'No pubspec.yaml found for workspace path "$relativePath".',
        );
        exit(1);
      }
      final packageDoc = loadYaml(packagePubspec.readAsStringSync());
      final packageName = packageDoc['name']?.toString();
      if (packageName == null) {
        stderr.writeln('Package at "$relativePath" is missing a name.');
        exit(1);
      }
      packages[packageName] = _WorkspacePackage(
        name: packageName,
        path: relativePath,
      );
    }
  }

  return packages;
}

_LineColumn _offsetToLineColumn(String source, int offset) {
  var line = 1;
  var column = 1;
  for (var i = 0; i < offset && i < source.length; i++) {
    if (source[i] == '\n') {
      line += 1;
      column = 1;
    } else {
      column += 1;
    }
  }
  return _LineColumn(line: line, column: column);
}

class _PackageRule {
  const _PackageRule({
    required this.name,
    required this.path,
    required this.allowedPackages,
  });

  final String name;
  final String path;
  final Set<String> allowedPackages;
}

class _WorkspacePackage {
  const _WorkspacePackage({required this.name, required this.path});

  final String name;
  final String path;
}

class _ImportViolation {
  const _ImportViolation({
    required this.sourcePackage,
    required this.targetPackage,
    required this.filePath,
    required this.line,
    required this.column,
  });

  final String sourcePackage;
  final String targetPackage;
  final String filePath;
  final int line;
  final int column;
}

class _LineColumn {
  const _LineColumn({required this.line, required this.column});

  final int line;
  final int column;
}
