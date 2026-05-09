# Codex Instructions for `flutter_app`

This file applies to all work under `flutter_app`.

## Scope

- Keep Flutter changes limited to the files needed for the user's request.
- Before editing, inspect only the relevant files and nearby dependencies.
- Do not run broad project-wide checks by default.

## Formatting

- Format only Dart files changed in the current task.
- Prefer:

```bash
dart format path/to/changed_file.dart
```

- Do not run `dart format .`, `dart format lib`, or format unrelated files unless the user explicitly asks.

## Analysis

- Analyze only changed Dart files when possible.
- Prefer:

```bash
dart analyze path/to/changed_file.dart
```

- Do not run full-project `flutter analyze` unless:
  - the change touches shared configuration or generated code,
  - the user asks for a full check,
  - or a focused check cannot validate the change.

## Diff Review

- Review diffs only for files changed in the current task.
- Prefer:

```bash
git diff -- path/to/changed_file.dart
```

- Do not inspect or summarize unrelated diffs.

## Pub and Generated Files

- Do not run commands that may update `pubspec.lock` unless dependencies were intentionally changed.
- Do not regenerate `*.g.dart`, `*.freezed.dart`, or other generated files unless the edited model/schema requires it.

## Running the App

- If a dev server or emulator run is needed, explain the target platform and URL/device before starting it.
- For Android emulator API calls, `10.0.2.2` maps to host `localhost`.
- For physical Android devices, use the host machine LAN IP instead of `10.0.2.2`.
