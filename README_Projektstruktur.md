
## Projektstruktur (Kurzbeschreibung)

Dieses Dokument beschreibt die wesentliche Projektstruktur des Flutter-Projekts. Aufgeführt werden die README-Dateien im Projekt-Root, die `pubspec.yaml`-Datei sowie die Verzeichnisse `lib/` und – sofern vorhanden – `assets/` (rekursiv) mit einer kurzen Erklärung, welche Artefakte dort abgelegt werden.

## Projekt - Verzeichnisbaum (relevant für dieses README)

```
.
├── README.md
├── README_Projektstruktur.md
├── pubspec.yaml
├── .github/
│   └── copilot-instructions.md
├── assets/
│   └── room_creator/
│       ├── app.js
│       ├── index.html
│       └── styles.css
└── lib/
	├── main.dart
	├── blocs/
	│   ├── json_hot_reload/
	│   │   ├── json_hot_reload_bloc.dart
	│   │   ├── json_hot_reload_event.dart
	│   │   └── json_hot_reload_state.dart
	│   ├── landing_page/
	│   │   ├── landing_page_bloc.dart
	│   │   ├── landing_page_event.dart
	│   │   └── landing_page_state.dart
	│   ├── measurement_page/
	│   │   ├── measurement_page_bloc.dart
	│   │   ├── measurement_page_event.dart
	│   │   └── measurement_page_state.dart
	│   └── simulation_page/
	│       ├── simulation_page_bloc.dart
	│       ├── simulation_page_event.dart
	│       └── simulation_page_state.dart
	├── constants/
	│   └── app_constants.dart
	├── l10n/
	│   ├── configuration/
	│   │   └── default_configuration.json
	│   ├── json_parser.dart
	│   ├── themes/
	│   │   ├── dark.json
	│   │   └── light.json
	│   └── translations/
	│       ├── de.json
	│       └── us.json
	├── utilities/
	│   └── ui/
	│       └── common/
	│           ├── sonalyze_accordion_tile.dart
	│           ├── sonalyze_button.dart
	│           └── sonalyze_surface.dart
	├── services/
	│   └── room_creation/
	│       └── room_creation_loader.dart
	└── views/
		├── landing_page/
		│   └── landing_page.dart
		├── measurement_page/
		│   └── measurement_page.dart
		└── simulation_page/
			└── simulation_page.dart
```

> Hinweis: Das Verzeichnis `assets/room_creator/` liefert das eingebettete HTML/JS-Demo für den Room-Creation-Loader (siehe Abschnitt „`assets/` (statische Ressourcen)“).

## Root-Dateien

- `README.md` — Allgemeine Projekt-Informationen, How-to, Entwicklerhinweise.
- `README_Projektstruktur.md` — Dieses Dokument: Detaillierte Beschreibung der Ordnerstruktur.
- `pubspec.yaml` — Abhängigkeiten, Assets-Registrierung, App-Metadaten (App-Name, Version, Fonts usw.).
- `.github/copilot-instructions.md` — Handlungsanweisungen für AI-Coding-Agents (Coding-Guidelines, Projekt-Kontext).

## `lib/` (Quellcode)

In `lib/` befindet sich der gesamte Dart-/Flutter-Quellcode der App. Die aktuelle Verzeichnisstruktur ist oben als Baum dargestellt. Die wichtigsten Ordner im Detail:

- `main.dart`
	- Einstiegspunkt der App. Stellt sicher, dass `AppConstants.initialize()` ausgeführt wird und registriert die Routen (`/`, `/simulation`, `/measurement`).

- `blocs/`
	- Feature-spezifische BLoCs.
	- `json_hot_reload/` — Beobachtet die JSON-Konfigurationsdateien und lädt sie bei Änderungen im Desktop-Modus nach.
	- `landing_page/` — Steuert Demo-Inhalte der Landing Page (Feature-Rotation, FAQ, Kontaktformular-Simulation).
	- `measurement_page/` — Simuliert Lobbys, Geräte und Telemetrie der Measurement Page.
	- `simulation_page/` — Verarbeitet Raumparameter, Presets und Möbelplatzierungen für die Simulation.

- `constants/`
	- `app_constants.dart` — Kapselt den Zugriff auf Konfigurations-, Theme- und Übersetzungsdaten.

- `l10n/`
	- `json_parser.dart` — Hilfsklasse zum dynamischen Laden/Mergen der JSON-Dateien.
	- `configuration/` — Standardkonfigurationen (`default_configuration.json`).
	- `themes/` — Theme-Dateien (`dark.json`, `light.json`).
	- `translations/` — Sprachressourcen (`de.json`, `us.json`).

- `utilities/ui/common/`
	- Wiederverwendbare UI-Bausteine (z. B. `SonalyzeButton`, `SonalyzeSurface`, `SonalyzeAccordionTile`) für ein konsistentes Erscheinungsbild.

- `services/`
	- Integrationslogik für externe/technologieübergreifende Komponenten. `room_creation/room_creation_loader.dart` lädt das HTML/JS-Raum-Tool per `flutter_inappwebview` und stellt Messaging-Hooks bereit.

- `views/`
	- Feature-spezifische Screens als Widgets.
	- `landing_page/landing_page.dart` — Komplettes Landing-Page-Layout mit BLoC-Anbindung.
	- `measurement_page/measurement_page.dart` — Screens & Komponenten für Messungs-Workflows.
	- `simulation_page/simulation_page.dart` — UI für die akustische Simulation (Konfigurator, Grid, Charts).

## `assets/` (statische Ressourcen)

- `room_creator/` — Beinhaltet das HTML/JS/CSS-Demo für den Room-Creation-Loader (`index.html`, `app.js`, `styles.css`). Die Dateien sind in `pubspec.yaml` als Flutter-Assets registriert.

Gute Praktiken für `assets/`:

- Assets in `pubspec.yaml` unter `flutter:` → `assets:` bzw. `fonts:` registrieren.
- Ordner klar nach Zweck trennen und sprechende Dateinamen vergeben.
- Bilddateien optimieren (Kompression, Auflösung) bevor sie eingecheckt werden.

## Kurze Checkliste für Entwickler

- Neue JSON-Konfigurationen oder Übersetzungen → in `lib/l10n/` ablegen und ggf. `JsonHotReloadBloc` berücksichtigen.
- Neue State-Logik → passendes Feature unter `lib/blocs/` erweitern.
- UI-Erweiterungen → in den jeweiligen `lib/views/<feature>/`-Ordnern oder als wiederverwendbare Komponenten unter `lib/utilities/ui/common/` ergänzen.
- Assets hinzufügen → `assets/` anlegen/strukturieren und `pubspec.yaml` aktualisieren.

## Abschluss

Dieses README bildet den aktuellen Stand der Projektstruktur ab. Bitte abgestimmte Änderungen hier dokumentieren, damit das Team sowie AI-Agents stets denselben Überblick besitzen.

