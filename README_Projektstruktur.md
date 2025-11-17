
## Projektstruktur (Kurzbeschreibung)

Dieses Dokument beschreibt die aktuelle Projektstruktur des Flutter-Projekts. Der Fokus liegt auf den Root-Dateien, dem Melos-Workspace unter `packages/` sowie dem verbleibenden Code im App-Paket (`lib/`).

## Projekt - Verzeichnisbaum (relevant für dieses README)

```
.
├── README.md
├── README_Projektstruktur.md
├── README_REFACTORING_PLAN.md
├── pubspec.yaml
├── melos.yaml
├── .github/
│   └── copilot-instructions.md
├── packages/
│   ├── README.md
│   ├── core/
│   │   └── ui/
│   │       ├── lib/
│   │       │   ├── core_ui.dart
│   │       │   └── src/common/
│   │       │       ├── sonalyze_surface.dart
│   │       │       ├── sonalyze_button.dart
│   │       │       └── sonalyze_accordion_tile.dart
│   │       └── README.md
│   ├── services/
│   │   └── l10n/
│   │       ├── assets/
│   │       │   ├── configuration/
│   │       │   ├── themes/
│   │       │   └── translations/
│   │       └── lib/
│   │           ├── l10n_service.dart
│   │           └── src/
│   │               ├── app_constants.dart
│   │               ├── json_parser.dart
│   │               └── json_hot_reload/
│   ├── features/
│   │   ├── landing_page/
│   │   │   └── lib/
│   │   │       ├── landing_page.dart
│   │   │       └── src/
│   │   │           ├── bloc/
│   │   │           │   ├── landing_page_bloc.dart
│   │   │           │   ├── landing_page_event.dart
│   │   │           │   └── landing_page_state.dart
│   │   │           └── view/landing_page_screen.dart
│   │   ├── measurement_page/
│   │   │   └── lib/
│   │   │       ├── measurement_page.dart
│   │   │       └── src/
│   │   │           ├── bloc/
│   │   │           │   ├── measurement_page_bloc.dart
│   │   │           │   ├── measurement_page_event.dart
│   │   │           │   └── measurement_page_state.dart
│   │   │           └── view/measurement_page_screen.dart
│   │   └── simulation_page/
│   │       └── lib/
│   │           ├── simulation_page.dart
│   │           └── src/
│   │               ├── bloc/
│   │               │   ├── simulation_page_bloc.dart
│   │               │   ├── simulation_page_event.dart
│   │               │   └── simulation_page_state.dart
│   │               └── view/simulation_page_screen.dart
│   └── helpers/
│       └── common/
│           ├── lib/
│           │   ├── common_helpers.dart
│           │   └── src/
│           │       └── number_formatting.dart
│           └── README.md
└── lib/
  ├── di/
  │   └── injector.dart
  └── main.dart
```

> Hinweis: Alle Feature-spezifischen Blöcke, Views und Assets befinden sich nun in eigenen Paketen unter `packages/`. Das App-Paket enthält nur noch den Einstiegspunkt und ggf. zukünftige App-spezifische Glue-Code-Dateien (`di/`, `router/` usw.).

## Root-Dateien

- `README.md` — Allgemeine Projekt-Informationen, How-to, Entwicklerhinweise.
- `README_Projektstruktur.md` — Dieses Dokument.
- `README_REFACTORING_PLAN.md` — Schrittweiser Migrationsplan (u. a. für Melos, Feature-Pakete und `get_it`).
- `pubspec.yaml` — App-spezifische Abhängigkeiten (u. a. `l10n_service`, `core_ui`, alle Feature-Pakete) und Workspace-Angaben.
- `melos.yaml` — Melos-Workspace-Konfiguration inkl. Skripten für Bootstrap, Analyse, Tests und Formatierung.
- `.github/copilot-instructions.md` — Prozess- und Coding-Guidelines für AI-Agents.

## Melos-Workspace und `packages/`

Der Workspace bündelt sämtliche Pakete unter `packages/**`. Wichtige Bestandteile:

- **Skripte:**
  - `melos run bootstrap` installiert Abhängigkeiten und verknüpft alle Path-Dependencies.
  - `melos run analyze` führt `flutter analyze` in jedem Paket mit `pubspec.yaml` aus.
  - `melos run test` startet Paket-Tests (sofern ein `test/`-Ordner vorhanden ist).
  - `melos run format` formatiert pro Paket den jeweiligen `lib/`-Ordner.
- **Paketfamilien:**
  - `packages/core/ui` — Shared UI-Bausteine wie `SonalyzeSurface`, `SonalyzeButton`, Accordion-Tiles. Öffentliche API über `lib/core_ui.dart`.
  - `packages/services/l10n` — Lokalisation + JSON-Konfigurationen (`AppConstants`, `JsonParser`, `JsonHotReloadBloc` samt Assets unter `assets/`).
  - `packages/features/landing_page` — Landing-Page-Screen inkl. `LandingPageBloc`, Demo-Daten, kompletter View-Tree.
  - `packages/features/measurement_page` — Measurement-Flow mit Lobby-, Gerätelisten-, Telemetrie- und Timeline-Widgets plus zugehörigem Bloc.
  - `packages/features/simulation_page` — Simulation-Sandbox (Konfigurator, Grid, Kennzahlen) samt BLoC und akustischen Helfern.
  - `packages/helpers/common` — Pure-Dart stateless Helper-Funktionen (aktuell z. B. `formatNumber`, `roundToDigits`).

Alle Pakete verwenden das `lib/` + `lib/src/`-Konventionsmuster: Die öffentliche API wird ausschließlich über `lib/<paketname>.dart` exportiert, Implementierungen verbleiben in `lib/src/`.

## `lib/` (App-spezifischer Code)

Nach der Modularisierung enthält das App-Paket nur noch den Einstiegspunkt:

- `main.dart`
  - Initialisiert `AppConstants` aus `l10n_service`.
  - Baut das `MaterialApp`, erzeugt das Theme über die JSON-Design-Tokens.
  - Registriert alle Feature-Routen und importiert die Screens direkt aus den Feature-Paketen (`package:landing_page/…`, `package:measurement_page/…`, `package:simulation_page/…`).
  - Ist der einzige Ort, an dem zukünftig DI (`get_it`) oder globale Router-Logik zusammenlaufen.

Weitere App-spezifische Dateien liegen ausschließlich im `lib/di/`-Ordner (derzeit `injector.dart`). Layout-Shells oder Router-Erweiterungen würden ebenfalls dort entstehen, ohne in Feature-Code einzugreifen.

## Assets und Übersetzungen

- Alle Konfigurations-, Theme- und Übersetzungsdateien liegen unter `packages/services/l10n/assets/` (`configuration/`, `themes/`, `translations/`).
- Das Service-Paket registriert die Assets in seiner eigenen `pubspec.yaml` und stellt Zugriffsfunktionen (`AppConstants.config`, `AppConstants.translation`, `AppConstants.getThemeColor`) bereit.
- Desktop-Hot-Reload für JSON-Dateien erfolgt über `JsonHotReloadBloc`, ebenfalls Teil des `l10n_service`-Pakets.
- Sollten zusätzliche statische Assets benötigt werden (Bilder, Fonts usw.), können sie entweder im App-Paket oder in einem passenden Feature-/Core-Paket angelegt werden. In jedem Fall gehören sie in die jeweilige `pubspec.yaml` unter `flutter:` → `assets:` bzw. `fonts:`.

## Kurze Checkliste für Entwickler

- **Lokalisierung/Themes:** Änderungen an Konfiguration, Themes oder Übersetzungen → `packages/services/l10n/assets/` + ggf. `JsonHotReloadBloc` anstoßen.
- **Shared UI:** Neue wiederverwendbare Widgets → `packages/core/ui/lib/src/…` implementieren und über `lib/core_ui.dart` exportieren.
- **Feature-Code:** UI + BLoC-Logik ausschließlich im jeweiligen Feature-Paket ergänzen (`lib/src/view`, `lib/src/bloc`). Keine direkten Abhängigkeiten zwischen Features; stattdessen Services/Core verwenden oder Callbacks nach außen reichen.
- **App-Glue:** Route-/DI-Anpassungen sowie globale Theme- oder State-Wiring geschehen in `lib/main.dart` (später ggf. `lib/di/`).
- **Neue Pakete:** Beim Anlegen weiterer Features/Services unbedingt das `lib/` vs. `lib/src/`-Pattern sowie die Abhängigkeitsregeln aus `packages/README.md` beachten.

## Abschluss

Dieses README dokumentiert den aktuellen Stand der Feature-First-/Melos-Struktur. Bitte bei weiteren Umstrukturierungen (neue Pakete, Assets, Routing, DI) die entsprechenden Abschnitte aktualisieren, damit das gesamte Team – inklusive AI-Agents – synchron bleibt.

