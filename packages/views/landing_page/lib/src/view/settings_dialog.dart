import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n_service/l10n_service.dart';
import 'package:core_ui/core_ui.dart';

class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.watch<JsonHotReloadBloc>();
    final activeTheme = bloc.activeTheme ?? 'dark';
    final activeLanguage = bloc.activeLanguage ?? 'us';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: SonalyzeSurface(
        padding: const EdgeInsets.all(24),
        borderRadius: BorderRadius.circular(24),
        backgroundColor: AppConstants.getThemeColor('app.surface'),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppConstants.translation('landing_page.settings_dialog.title') as String? ?? 'Settings',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSectionTitle(context, AppConstants.translation('landing_page.settings_dialog.theme_section') as String? ?? 'Theme'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _OptionButton(
                      label: AppConstants.translation('landing_page.settings_dialog.theme.light') as String? ?? 'Light',
                      icon: Icons.light_mode,
                      isSelected: activeTheme == 'light',
                      onTap: () => context.read<JsonHotReloadBloc>().add(
                        SetActiveTheme('light'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _OptionButton(
                      label: AppConstants.translation('landing_page.settings_dialog.theme.dark') as String? ?? 'Dark',
                      icon: Icons.dark_mode,
                      isSelected: activeTheme == 'dark',
                      onTap: () => context.read<JsonHotReloadBloc>().add(
                        SetActiveTheme('dark'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSectionTitle(context, AppConstants.translation('landing_page.settings_dialog.language_section') as String? ?? 'Language'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _OptionButton(
                      label: AppConstants.translation('landing_page.settings_dialog.language.english') as String? ?? 'English',
                      countryCode: 'us',
                      isSelected: activeLanguage == 'us',
                      onTap: () => context.read<JsonHotReloadBloc>().add(
                        SetActiveLanguage('us'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _OptionButton(
                      label: AppConstants.translation('landing_page.settings_dialog.language.german') as String? ?? 'Deutsch',
                      countryCode: 'de',
                      isSelected: activeLanguage == 'de',
                      onTap: () => context.read<JsonHotReloadBloc>().add(
                        SetActiveLanguage('de'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
    this.countryCode,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;
  final String? countryCode;

  @override
  Widget build(BuildContext context) {
    final selectedColor = AppConstants.getThemeColor('app.primary');
    final unselectedColor = Colors.transparent;
    final borderColor = AppConstants.getThemeColor(
      'app.on_surface',
    ).withValues(alpha: 0.2);
    final textColor = Theme.of(context).colorScheme.onSurface;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor.withValues(alpha: 0.15)
              : unselectedColor,
          border: Border.all(
            color: isSelected ? selectedColor : borderColor,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (countryCode != null) ...[
              SonalyzeFlag(countryCode: countryCode!, width: 24, height: 16),
              const SizedBox(width: 8),
            ],
            if (icon != null) ...[
              Icon(
                icon,
                size: 20,
                color: isSelected ? selectedColor : textColor,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: isSelected ? selectedColor : textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
