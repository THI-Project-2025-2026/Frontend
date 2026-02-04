import 'package:flutter/material.dart';
import 'package:l10n_service/l10n_service.dart';

String _translate(String scopedKey) {
  final value = AppConstants.translation('room_modeling.$scopedKey');
  if (value is String && value.isNotEmpty) {
    return value;
  }
  return scopedKey;
}

/// Convenience helpers for accessing room modeling translations.
class RoomModelingL10n {
  static String text(String scopedKey) => _translate(scopedKey);

  static String format(String scopedKey, Map<String, String> params) {
    var result = text(scopedKey);
    params.forEach((placeholder, replacement) {
      result = result.replaceAll('{$placeholder}', replacement);
    });
    return result;
  }

  static String metersSuffix() => text('units.meters_suffix');

  static String degreesSuffix() => text('units.degrees_suffix');

  /// Translate material display name using material ID.
  /// Falls back to original displayName if translation not found.
  static String translateMaterial(String materialId, String displayName) {
    final value = AppConstants.translation('materials.$materialId');
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return displayName;
  }
}

/// Wrapper for fetching room modeling palette colors.
class RoomModelingColors {
  static Color color(String scopedKey) {
    return AppConstants.getThemeColor('room_modeling.$scopedKey');
  }
}
