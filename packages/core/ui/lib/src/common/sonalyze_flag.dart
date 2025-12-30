import 'package:flutter/material.dart';
import 'package:country_flags/country_flags.dart';

class SonalyzeFlag extends StatelessWidget {
  const SonalyzeFlag({
    super.key,
    required this.countryCode,
    this.width = 24,
    this.height = 16,
  });

  final String countryCode;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: width,
        height: height,
        child: CountryFlag.fromCountryCode(countryCode),
      ),
    );
  }
}
