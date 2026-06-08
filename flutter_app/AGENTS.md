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

---

## Architecture Notes

### Call System (WebRTC, global)

Call signaling is wired at the **provider level**, not the screen level. This allows incoming calls to be received from any screen.

Key files:
- `lib/features/call/presentation/call_provider.dart` — `callProvider` is a **non-autoDispose** `StateNotifierProvider`. Persists across navigation. Handles `call_offer`, `call_answer`, `call_ice_candidate`, `call_end`, `call_reject`, `call_busy` in `handleSignalingMessage()`.
- `lib/features/call/presentation/incoming_call_screen.dart` — Full-screen call UI with accept/reject/mute/end buttons. Auto-plays ringtone + vibration on incoming calls.
- `lib/features/call/data/call_ringtone_service.dart` — Plays system ringtone + vibration loop via MethodChannel (`sports_venue_chatbot/call_ringtone`).
- `lib/features/call/presentation/call_overlay.dart` — Legacy overlay widget (still exports `CallButton` for chat screens).
- `lib/features/call/data/call_service.dart` — WebRTC peer connection management.

Signaling flow:
1. `StaffChatNotifier` (provider, not screen) sets `onCallSignaling` in its constructor via `staffChatProvider` family provider.
2. When `call_offer` arrives on the chat WebSocket, `onCallSignaling` forwards it to `CallNotifier.handleSignalingMessage()`.
3. `CallNotifier` updates state → `incomingRinging`.
4. `_GlobalCallListener` in `main.dart` detects the state change → pushes `/call` route.
5. `IncomingCallScreen` starts ringtone/vibration, shows accept/reject UI.
6. On accept → WebRTC answer sent via same WebSocket. On end → state resets → auto-pop.

Important: `callProvider` must NOT be autoDispose. The `attachSignaling` callback is set per chat room (family provider), so only the most recently opened chat room's WebSocket is used for signaling.

### Notification System (WebSocket-based)

Two separate WebSocket connections to `/api/realtime/notifications`:

1. **Staff/Admin notifications** — `lib/features/staff/presentation/staff_notifications_provider.dart`
   - Started for STAFF/ADMIN roles only.
   - Receives `StaffNotification` objects, shows native notifications via `LocalNotificationService`.
   - Handles `ui_event` types: `payment_status_changed`, `order_changed`.

2. **Customer chat notifications** — `lib/features/staff_chat/presentation/customer_chat_notifications_provider.dart`
   - Started for CUSTOMER role only.
   - Handles events: `staff_chat_message` (from staff), `court_status_changed`, `staff_request_accepted` / `staff_request`.
   - `staff_request_accepted` → shows native notification "Nhân viên đã tiếp nhận yêu cầu" to customer.

Lifecycle managed in `main.dart` via `_syncRealtimeNotifications()` — called on auth state changes.

### Routing (GoRouter)

Route structure:
- `/splash`, `/login`, `/scan-qr` — top-level
- Customer shell (`HomeScreen`): `/home`, `/chat`, `/booking`, `/menu`, `/billing`, `/profile`, `/settings`
- Management shell (`RoleBasedShell`): `/admin/*`, `/staff/*`
- Top-level routes: `/admin/analytics`, `/admin/resource-pricing`, `/admin/notifications`, `/payment`, `/voice-agent`, `/call`, `/staff-chat/:requestId`, `/staff-operator-chat/:requestId`

### Native Android (MainActivity.kt)

MethodChannels:
- `sports_venue_chatbot/notifications` — `showOperationNotification(title, body)`
- `sports_venue_chatbot/vnpay` — `openVnpaySdk(paymentUrl, tmnCode, isSandbox)`
- `sports_venue_chatbot/call_ringtone` — `startRingtone()`, `stopRingtone()` (uses `RingtoneManager` + `Vibrator`)
