# Repository Guidelines

## Project Structure & Module Organization
Source for the public API lives in `lib/`, with reusable widgets under `lib/src/` (e.g., `cyclic_tab_bar_view.dart` and controllers). The showcase app in `example/` is the fastest place to verify UI changes and mirrors the package API. Tests reside in `test/`, mirroring the structure of `lib/` so every core widget/controller has a matching spec file. Shared analyzer and lint settings are in `analysis_options.yaml`; update it alongside `pubspec.yaml` whenever dependencies or lint rules change.

## Build, Test, and Development Commands
- `flutter analyze`: static analysis using the repo's lint rules; run before committing.
- `dart format .`: apply standard 2-space indentation and trailing commas; required before reviews.
- `flutter test --coverage`: executes the package tests and refreshes `coverage/lcov.info` locally.
- `flutter run example/lib/main.dart`: boots the example app to validate scroll + tab interactions end-to-end.

## Coding Style & Naming Conventions
Follow idiomatic Dart style with 2-space indentation, final/const where possible, and trailing commas to keep widget diffs small. Public APIs should use PascalCase classes and camelCase methods/fields; private helpers get a leading underscore. Keep files focused: widgets in `cyclic_tab_bar_widget.dart`, controllers in `cyclic_tab_controller.dart`, and avoid mixing UI with calculations. Prefer extension methods over utility classes, and document non-obvious math with short comments.

## Testing Guidelines
Widget and controller tests belong in `test/`, named `<feature>_test.dart` (e.g., `cyclic_tab_controller_test.dart`). Use the Flutter test framework with `testWidgets` for UI flows and plain `test` for controller math. Every new behavior should add regression coverage plus golden snapshots whenever the tab view visuals change. Failures inside the example app need a matching automated test before merging.

## Commit & Pull Request Guidelines
Commits follow the conventional style already in history (`feat:`, `fix:`, `refactor:`) so changelogs stay tidy. Each PR should include: a concise summary, screenshots/GIFs when UI shifts, reproduction steps for bugs, and a note about tests run. Reference related issues in the PR body using `Fixes #ID` so GitHub can auto-close them. Avoid stacking unrelated changes; keep PRs scoped to a single feature or bugfix.
