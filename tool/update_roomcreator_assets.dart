import 'dart:io';

import 'package:path/path.dart' as p;

const _repoUrl =
    'https://github.com/THI-Project-2025-2026/Frontend-RoomCreator';

Future<void> main() async {
  final scriptDir = File(Platform.script.toFilePath()).parent;
  final rootDir = p.normalize(p.join(scriptDir.path, '..'));
  final assetsDir = Directory(
    p.join(rootDir, 'assets', 'frontend_roomcreator'),
  );

  final tmpDir = await Directory.systemTemp.createTemp('roomcreator-');
  try {
    final cloneDir = Directory(p.join(tmpDir.path, 'Frontend-RoomCreator'));
    stdout.writeln('Cloning RoomCreator sources...');
    await _runCommand('git', [
      'clone',
      '--depth',
      '1',
      _repoUrl,
      cloneDir.path,
    ]);

    final assetSrc = Directory(
      p.join(cloneDir.path, 'dist', 'room-creator', 'browser'),
    );
    final licenseSrc = File(
      p.join(cloneDir.path, 'dist', 'room-creator', '3rdpartylicenses.txt'),
    );

    if (!await assetSrc.exists()) {
      throw StateError(
        'Expected built assets in ${assetSrc.path} but none were found.',
      );
    }

    if (await assetsDir.exists()) {
      await assetsDir.delete(recursive: true);
    }
    await assetsDir.create(recursive: true);
    await _copyDirectory(assetSrc, assetsDir);

    if (await licenseSrc.exists()) {
      await licenseSrc.copy(p.join(assetsDir.path, '3rdpartylicenses.txt'));
    }

    final commitHash = await _runCommand('git', [
      '-C',
      cloneDir.path,
      'rev-parse',
      'HEAD',
    ]);
    final versionFile = File(p.join(assetsDir.path, 'version.txt'));
    await versionFile.writeAsString('source_commit: ${commitHash.trim()}\n');

    stdout.writeln('RoomCreator assets updated to commit ${commitHash.trim()}');
  } finally {
    await tmpDir.delete(recursive: true);
  }
}

Future<void> _copyDirectory(Directory source, Directory destination) async {
  await destination.create(recursive: true);
  await for (final entity in source.list(
    recursive: false,
    followLinks: false,
  )) {
    final newPath = p.join(destination.path, p.basename(entity.path));
    if (entity is File) {
      await entity.copy(newPath);
    } else if (entity is Directory) {
      await _copyDirectory(entity, Directory(newPath));
    }
  }
}

Future<String> _runCommand(String executable, List<String> arguments) async {
  final result = await Process.run(executable, arguments);
  if (result.exitCode != 0) {
    final stdoutStr = (result.stdout ?? '').toString();
    final stderrStr = (result.stderr ?? '').toString();
    throw ProcessException(
      executable,
      arguments,
      'Command failed with exit code ${result.exitCode}\n$stdoutStr$stderrStr',
      result.exitCode,
    );
  }
  return (result.stdout ?? '').toString();
}
