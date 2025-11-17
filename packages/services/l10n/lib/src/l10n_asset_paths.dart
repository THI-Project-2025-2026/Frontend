/// Provides canonical file system and asset paths for l10n resources.
class L10nAssetPaths {
  static const String _fileBase = 'packages/services/l10n/assets';
  static const String _assetBase = 'packages/l10n_service/assets';

  static const String configurationDirectory = '$_fileBase/configuration';
  static const String themesDirectory = '$_fileBase/themes';
  static const String translationsDirectory = '$_fileBase/translations';

  static AssetPathPair configuration(String fileName) => AssetPathPair(
    file: '$configurationDirectory/$fileName',
    asset: '$_assetBase/configuration/$fileName',
  );

  static AssetPathPair defaultConfiguration() =>
      configuration('default_configuration.json');

  static AssetPathPair theme(String themeName) => AssetPathPair(
    file: '$themesDirectory/$themeName.json',
    asset: '$_assetBase/themes/$themeName.json',
  );

  static AssetPathPair translation(String languageCode) => AssetPathPair(
    file: '$translationsDirectory/$languageCode.json',
    asset: '$_assetBase/translations/$languageCode.json',
  );

  static String assetFromFilePath(String filePath) {
    if (!filePath.startsWith(_fileBase)) {
      return filePath;
    }
    final relative = filePath.substring(_fileBase.length);
    final normalized = relative.startsWith('/')
        ? relative.substring(1)
        : relative;
    return '$_assetBase/$normalized';
  }
}

/// Holds both the file-system path (for desktop/mobile dev hot reload) and the
/// asset bundle path (for bundled/web builds) to the same JSON resource.
class AssetPathPair {
  const AssetPathPair({required this.file, required this.asset});

  final String file;
  final String asset;
}
