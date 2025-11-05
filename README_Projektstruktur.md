
## Projektstruktur (Kurzbeschreibung)

Dieses Dokument beschreibt die wesentliche Projektstruktur des Flutter-Projekts. Aufgeführt werden nur die README-Dateien im Projekt-Root, die `pubspec.yaml`-Datei sowie die Verzeichnisse `lib/` und `assets/` (rekursiv) mit einer kurzen Erklärung, welche Artefakte dort abgelegt werden sollten.

## Projekt - Verzeichnisbaum (relevant für dieses README)

```
.
├── README.md
├── README_Projektstruktur.md
├── pubspec.yaml
├── lib/
│   ├── main.dart
│   ├── blocs/
│   ├── cubits/
│   ├── services/
│   ├── utilities/
│   └── views/
└── assets/
	└── icons/
```

## Root-Dateien

- `README.md` — Allgemeine Projekt-Informationen, How-to, Entwicklerhinweise.
- `README_Projektstruktur.md` — Dieses Dokument: Detaillierte Beschreibung der Ordnerstruktur.
- `pubspec.yaml` — Abhängigkeiten, Assets-Registrierung, App-Metadaten (App-Name, Version, Fonts usw.).

## `lib/` (Quellcode)

In `lib/` befindet sich der gesamte Dart-/Flutter-Quellcode der App. Die aktuelle Verzeichnisstruktur ist:

- lib/
	- blocs/
	- cubits/
	- main.dart
	- services/
	- utilities
	- views/

Erklärung der einzelnen Ordner/Dateien:

- `main.dart`
	- Einstiegspunkt der App. Initialisiert Services, Themes, Routen und startet die App mit `runApp()`.

- `blocs/`
	- Enthält BLoC-Klassen (Business Logic Components) für komplexere Zustandsmaschinen und event-getriebene Logik. Hier kommen Events, States und BLoC-Implementierungen hin.
	- Typische Inhalte: `auth_bloc.dart`, `settings_bloc.dart`, event-/state-definitionen und ggf. `bloc_observer`-Konfiguration.

- `cubits/`
	- Für einfachere State-Management-Fälle, die sich gut mit Cubits abbilden lassen (leichtere Alternative zu vollständigen BLoCs).
	- Typische Inhalte: `theme_cubit.dart`, `locale_cubit.dart`, `simple_form_cubit.dart`.

- `services/`
	- Klassen, die externe Dienste kapseln: API-Clients, Repositories, Datenbanken, lokale Storage-Adapter, Auth-Provider, Push-Notification-Wrapper, etc.
	- Trennung von Schnittstellen (abstract classes) und Implementierungen ist empfohlen, um Testbarkeit zu erhöhen.

- `utilities/`
	- Allgemeine Hilfsfunktionen, Extensions, Konstanten, Enums und kleine Helper-Klassen. Beispiele: `date_utils.dart`, `validators.dart`, `app_constants.dart`, `extensions.dart`.

- `views/`
	- Alle UI-Bildschirme (Screens) und größere Widgets. Hier können weitere Unterordner wie `screens/`, `widgets/` oder `components/` angelegt werden.
	- Empfehlungen:
		- `views/screens/` → einzelne Seiten (z. B. `login_screen.dart`, `home_screen.dart`).
		- `views/widgets/` → wiederverwendbare UI-Komponenten (z. B. `primary_button.dart`, `custom_appbar.dart`).

Hinweise zur Organisation:

- Behalte eine klare Trennung zwischen Präsentation (UI in `views/`), Logik (in `blocs/`/`cubits/`) und Datenzugriff/Services (`services/`).
- Module/Feature-Ordner (feature-first) sind optional: Bei wachsendem Projekt kann es sinnvoll sein, nach Feature zu strukturieren (z. B. `lib/features/auth/...`).

## `assets/` (statische Ressourcen)

In `assets/` liegen alle statischen Ressourcen der App (Bilder, Icons, Schriftarten, Lokalisationsdateien, etc.). Aktueller Inhalt:

- assets/
	- icons/

Was in `assets/` gehört und wie es zu strukturieren ist:

- `icons/` — App-Icons, Launcher-Icons, SVG- oder PNG-Icons, die in der UI verwendet werden.
- `images/` (empfohlen) — Screenshots, Hintergrundbilder, illustrative Grafiken. Nutze Unterordner wie `images/backgrounds/` oder `images/onboarding/`.
- `fonts/` — Benutzerdefinierte Schriftarten (bei Verwendung diese in `pubspec.yaml` registrieren).
- `svgs/` — Vektor-Icons im SVG-Format (bei Nutzung entsprechender Packages wie `flutter_svg`).
- `locales/` oder `i18n/` — Übersetzungsdateien (z. B. JSON/ARB) für die Internationalisierung.

Gute Praktiken für `assets/`:

- Organisiere Assets nach Typ und Zweck (z. B. `icons/`, `images/`, `fonts/`, `locales/`).
- Trage alle genutzten Assets in `pubspec.yaml` unter `flutter:` → `assets:` bzw. `fonts:` ein, damit Flutter sie in die App-Builds aufnimmt.
- Vermeide große, unübersichtliche Ordner; nutze sprechende Dateinamen und Unterordner.
- Optional: eine `assets/README.md` für Team-Konventionen (Benennung, Formate, Auflösung, Optimierungsregeln) anlegen.

## Kurze Checkliste für Entwickler

- Neue Bilder/Fonts → in `assets/` ablegen und `pubspec.yaml` aktualisieren.
- Neue State-Logik:
	- komplexe/Event-getriebene → `blocs/`
	- einfache Zustände → `cubits/`
- API-/Datenzugriffscode → `services/`
-- UI-Komponenten → `views/` (bei wiederverwendbaren Komponenten in `views/widgets/`).

## Abschluss

Dieses README beschreibt die aktuelle, einfache Struktur des Projekts. Bei wachsendem Projektumfang kann eine Feature-basiere Struktur sinnvoll sein. Bei Fragen zur Konvention oder beim Umstrukturieren bitte im Team abstimmen.

