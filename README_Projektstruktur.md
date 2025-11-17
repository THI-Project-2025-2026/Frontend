
## Projektstruktur (Kurzbeschreibung)

Dieses Dokument beschreibt die aktuelle Struktur des Flutter-/Melos-Workspaces. Es fasst zusammen, welche Pakete existieren, wie der App-Einstieg aufgebaut ist und welche Befehle bzw. Regeln beim Arbeiten zu beachten sind.

## Setup & Basisbefehle

```bash
flutter pub get
melos run bootstrap
melos run analyze
melos run lint:imports
melos run test
melos run format
```

- `tool/custom_analyze.dart` analysiert jedes Paket einzeln und beendet sich beim ersten Fehler.
- `tool/lint_imports.dart` liest `import_rules.yaml` und verhindert unerlaubte Cross-Package-Imports.
- `melos run test` startet Tests nur in Paketen mit `test/`-Ordner, `melos run format` formatiert alle `lib/`-Verzeichnisse.

## Architekturüberblick

- Root-`lib/` enthält ausschließlich `main.dart` und DI-Glue unter `lib/di/` (aktuell `injector.dart`).
- Fachliche Implementierung lebt in Paketen unter `packages/{core,services,features,helpers}`; jedes Paket folgt dem `lib/` + `lib/src/`-Pattern und exportiert nur über seinen Barrel (`lib/<paket>.dart`).
- `packages/services/l10n` vereint Konfig/Theme/Translation-JSONs, `AppConstants`, `JsonParser` und den `JsonHotReloadBloc`. Alle Screens beziehen Texte/Farben über diese APIs – niemals direkt aus Assets lesen.
- Feature-Pakete (Landing/Measurement/Simulation) bringen ihren Screen + Bloc selbst mit und stellen nur das Barrel bereit; UI-Unterbau sitzt in `packages/core/ui`, rein funktionale Utilities in `packages/helpers/common`.

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

## Abhängigkeitsregeln & Import-Linter

- `import_rules.yaml` definiert, welche Pakete andere Pakete importieren dürfen. Gruppen (`services`, `features`, `core`, `helpers`) referenzieren komplette Unterordner.
- Das App-Paket (`sonalyze_frontend`) darf nur `services` + `features` importieren. Feature-Pakete dürfen auf `core`, `services`, `helpers` zugreifen, aber niemals aufeinander.
- `core_ui` konsumiert ausschließlich `helpers` und `l10n_service`, `common_helpers` bleibt komplett abhängigkeitsfrei.
- `melos run lint:imports` bricht ab, sobald ein Paket gegen diese Regeln verstößt. Nach neuen Paketen oder Umbauten immer `pubspec.yaml` (workspace-Section) + `import_rules.yaml` synchron halten und anschließend `melos run bootstrap` ausführen.

## Root-Dateien

- `README.md` — Allgemeine Projekt-Informationen, How-to, Entwicklerhinweise.
- `README_Projektstruktur.md` — Dieses Dokument.
- `README_REFACTORING_PLAN.md` — Schrittweiser Migrationsplan (u. a. für Melos, Feature-Pakete und `get_it`).
- `pubspec.yaml` — App-spezifische Abhängigkeiten (u. a. `l10n_service`, `core_ui`, alle Feature-Pakete) und Workspace-Angaben.
- `melos.yaml` — Melos-Workspace-Konfiguration inkl. Skripten für Bootstrap, Analyse, Tests und Formatierung.
- `import_rules.yaml` — Definiert für jedes Paket, welche anderen Workspace-Pakete importiert werden dürfen (Basis für `melos run lint:imports`).
- `.github/copilot-instructions.md` — Prozess- und Coding-Guidelines für AI-Agents.

## Melos-Workspace und `packages/`

Der Workspace bündelt sämtliche Pakete unter `packages/**` und nutzt Melos-Skripte als einheitliche Eintrittspunkte:

- `melos run bootstrap` ruft intern `melos bootstrap` auf und verlinkt alle Path-Dependencies nach Änderungen an `pubspec.yaml` oder den Paketordnern.
- `melos run analyze` startet `flutter analyze --no-pub` pro Paket (siehe `tool/custom_analyze.dart`) und stoppt beim ersten Fehler inklusive farbiger Zusammenfassung.
- `melos run lint:imports` (siehe `tool/lint_imports.dart`) setzt die oben beschriebenen Abhängigkeitsregeln durch.
- `melos run test` führt `flutter test` nur in Paketen aus, die einen `test/`-Ordner besitzen, `melos run format` formatiert jeden Paket-`lib/`-Ordner mit `dart format`.

**Paketfamilien:**

- `packages/core/ui` – Shared UI-Bausteine wie `SonalyzeSurface`, `SonalyzeButton`, `SonalyzeAccordionTile`; öffentlicher Einstieg `lib/core_ui.dart`.
- `packages/services/l10n` – L10n-/Theme-/Konfig-Service inklusive Assets und `JsonHotReloadBloc`.
- `packages/features/landing_page`, `measurement_page`, `simulation_page` – Feature-Pakete mit Screen + Bloc unter `lib/src/{view,bloc}` und Barrel-Export.
- `packages/helpers/common` – Rein funktionale Helfer (`formatNumber`, `roundToDigits`…), keine Flutter-Abhängigkeit.

Alle Pakete halten strikt das `lib/` + `lib/src/`-Muster ein: öffentliche API via Barrel, Implementierungsdetails verbleiben unter `lib/src/**` und dürfen von außen nicht importiert werden.

## `lib/` (App-spezifischer Code)

Nach der Modularisierung enthält das App-Paket nur noch den Einstiegspunkt:

- `main.dart`
  - Ruft vor `runApp` `configureDependencies()` auf, was `AppConstants.initialize()` sowie den `JsonHotReloadBloc` über `get_it` registriert.
  - Baut das `MaterialApp`, erzeugt das Theme über die JSON-Design-Tokens aus `AppConstants` und registriert alle Feature-Routen (`LandingPageScreen.routeName`, …).
  - Bleibt die zentrale Stelle für Routing, theming und zukünftige App-weite Glue-Komponenten.

Weitere App-spezifische Dateien liegen ausschließlich im Ordner `lib/di/`. Aktuell beherbergt `injector.dart` die gesamte `get_it`-Konfiguration inklusive Desktop-spezifischem Start des JSON-Hot-Reloads (auf Web wird aufgrund fehlendem `dart:io` automatisch geblockt).

## Assets, Lokalisierung & Hot Reload

- Alle Konfigurations-, Theme- und Übersetzungsdateien liegen unter `packages/services/l10n/assets/{configuration,themes,translations}` und werden in der `pubspec.yaml` des Service-Pakets registriert.
- Zugriff erfolgt ausschließlich über `AppConstants.config('pfad')`, `AppConstants.translation('pfad')`, `AppConstants.getThemeColor('pfad')` bzw. `AppConstants.getThemeColors('pfad')` – keine Hardcodes im UI-Code.
- `JsonHotReloadBloc` (aus `l10n_service`) beobachtet im Desktop-Debug die aktiven JSON-Dateien im 500-ms-Intervall und lädt sie neu. Auf Web wird Watching automatisch deaktiviert (`kIsWeb`), man kann aber weiterhin Reload-Events dispatchen.
- Möchten Features neue Asset-Typen überwachen, wird der bestehende Bloc um neue Events/States erweitert; zusätzliche Watcher sind nicht nötig.
- Weitere statische Assets (z. B. Images) liegen entweder im App-Paket oder in einem passenden Feature/Core-Paket und müssen dort im jeweiligen `pubspec.yaml`-Abschnitt `flutter/assets` bzw. `fonts` eingetragen werden.

## Kurze Checkliste für Entwickler

- **Lokalisierung/Themes:** Änderungen an JSON-Dateien immer unter `packages/services/l10n/assets/` durchführen und den bestehenden `JsonHotReloadBloc` nutzen (Events erweitern statt neue Watcher bauen).
- **Shared UI:** Neue wiederverwendbare Widgets kommen nach `packages/core/ui/lib/src/...` und werden über `lib/core_ui.dart` exportiert; Designs lesen ihre Farben/Texte über `AppConstants` oder via Parameter.
- **Feature-Code:** Screens + Bloc-Logik bleiben im jeweiligen Feature-Paket unter `lib/src/view` bzw. `lib/src/bloc`. Features importieren keine anderen Features, sondern bedienen sich bei `core_ui`, `l10n_service`, `common_helpers`.
- **App-Glue/DI:** Anpassungen an Routing, globalem Theme oder Dependency Injection erfolgen ausschließlich in `lib/main.dart` und `lib/di/injector.dart` (hier `get_it`-Registrierungen pflegen).
- **Neue Pakete:** Immer Barrel + `lib/src`-Pattern einhalten, `pubspec.yaml` (root workspace + Paket) aktualisieren, `import_rules.yaml` ergänzen und danach `melos run bootstrap` + `melos run lint:imports` ausführen.

## Abschluss

Dieses README dokumentiert den aktuellen Stand der Feature-First-/Melos-Struktur. Bitte bei weiteren Umstrukturierungen (neue Pakete, Assets, Routing, DI) die entsprechenden Abschnitte aktualisieren, damit das gesamte Team – inklusive AI-Agents – synchron bleibt.

