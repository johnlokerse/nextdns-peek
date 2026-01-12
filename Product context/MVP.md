# MVP Context Doc — NextDNS Peek (macOS)

## Purpose

Build a **macOS menu bar app** that lets a user quickly **peek** at their **NextDNS statistics and recent logs**. The app is **read-only**, intended for **personal use**, and will be run via **local build** (Xcode). Primary interaction is a **status bar icon** that opens a **SwiftUI popover**.

## Success criteria

* User can open the menu bar popover and see:

  * A compact stats summary (e.g., total requests, blocked, block rate)
  * A preview of recent logs (last N entries)
* App refreshes data:

  * **Automatically on popover open/click**
  * Via **manual Refresh** button
  * Via **configurable background polling interval**
* API token is stored securely (Keychain)
* Robust handling for offline / unauthorised / rate-limited states

## Scope

### In scope (MVP)

* Menu bar status item + popover UI
* Read-only integration with NextDNS API:

  * Validate token and retrieve **single profile** (or let user set profile id)
  * Fetch **stats** for a chosen time window
  * Fetch **recent logs** (limit N)
* Preferences screen:

  * Store/replace/remove API token
  * Select refresh interval (Off / 1m / 5m / 15m)
  * Optional: privacy mode toggle (hide domain names)
* Caching/throttling:

  * In-memory cache of latest stats/logs
  * Skip refresh if last refresh was within a short threshold

### Out of scope (explicitly)

* Write operations (block/allow lists, config changes)
* Multi-profile support (only one profile)
* Persisting full historical logs locally (no SQLite/CoreData in MVP)
* Charts/advanced analytics (keep UI minimal)

## Target platform

* macOS (SwiftUI + AppKit status bar host)
* Distribution: **local install package** via **DMG** (or ZIP) generated from Xcode build output

## Build & install (local DMG)

Goal: produce a clickable installer artifact you can copy to your Mac and drag the app to `/Applications`.

### Recommended approach (simple, local)

1. In Xcode: **Product → Archive**
2. In Organizer: **Distribute App → Copy App** (or export the `.app`)
3. Create a DMG that contains:

   * `NextDNS Peek.app`
   * A shortcut to `/Applications`
4. User installs by dragging the app into `/Applications`

### Gatekeeper notes (local builds)

* Unsigned/unnotarised apps may be blocked by Gatekeeper.
* Options:

  * Sign with an Apple Developer ID certificate (best experience), optionally notarise.
  * For personal local use, you can also remove quarantine after download/transfer or allow via System Settings.

### Create DMG (automation-friendly)

Given an exported `.app`, create a basic DMG:

* Stage folder structure (e.g., `dist/`):

  * `dist/NextDNS Peek.app`
  * `dist/Applications` (symlink to `/Applications`)
* Create DMG with `hdiutil`.

Example commands:

```bash
APP_NAME="NextDNS Peek"
DIST_DIR="dist"
DMG_NAME="NextDNS-Peek"

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"
cp -R "build/$APP_NAME.app" "$DIST_DIR/"
ln -s /Applications "$DIST_DIR/Applications"

hdiutil create -volname "$APP_NAME" -srcfolder "$DIST_DIR" -ov -format UDZO "$DMG_NAME.dmg"
```

If you later sign + notarise, do it **before** DMG creation.

## UX specification

### Menu bar popover (primary)

When user clicks the status bar icon:

* Popover opens
* App triggers refresh-on-open (with throttle)
* Popover displays:

  1. Header

     * App name + profile name
     * “Last updated” timestamp
  2. Stats summary (compact)

     * Requests (time window)
     * Blocked (time window)
     * Block rate %
  3. Recent logs preview list

     * Rows: time, domain (redacted if privacy mode), decision (blocked/allowed), client/device (if available)
     * Limit: N (e.g., 20)
  4. Actions

     * Refresh
     * Open Logs… (optional window; can be deferred)
     * Preferences…
     * Quit

### Preferences

* API Token section

  * Token input/paste
  * Validate + Save
  * Remove token
* Refresh section

  * Interval dropdown: Off / 1m / 5m / 15m
  * Throttle seconds (optional advanced; can be hardcoded)
* Privacy section

  * Toggle: Hide domains (show only counts / redacted domains)
* Diagnostics section

  * Last refresh time
  * Last error message (if any)

## Key behaviours

### Refresh behaviour

* Refresh triggers:

  * `onPopoverAppear` (refresh-on-open)
  * Manual Refresh button
  * Timer based on configured interval (if not Off)
* Throttling:

  * If `now - lastRefreshAt < throttleSeconds` (e.g., 10–20s), skip refresh
* Backoff:

  * On HTTP 429: exponential backoff and show rate-limited indicator
  * On 5xx: retry once after short delay; then show error

### Offline and cached display

* If request fails due to network:

  * Show last cached stats/logs (if present)
  * Show “Offline” indicator

### Auth failures

* On HTTP 401/403:

  * Mark session unauthorised
  * Prompt in Preferences to re-enter token
  * Hide sensitive UI (optional) and show error state

## Security & storage

### API token storage (mandatory)

* Store token in **Keychain Services** as a **generic password**
* Use:

  * Service: `com.<yourbundle>.nextdns-peek`
  * Account: `nextdns-api-token`
* Accessibility:

  * Prefer `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` (works for menu bar refresh after login)
* Never log token or auth headers
* Provide “Remove token” action (delete Keychain item)

### Preferences storage

* Use `UserDefaults` for:

  * Refresh interval
  * Privacy mode
  * Selected time window for stats

## Technical architecture

### Suggested stack

* Swift + SwiftUI (UI)
* AppKit (`NSStatusBar`, `NSStatusItem`) to host status bar icon and popover
* URLSession + `async/await` for networking

### Modules/classes

* `NextDNSClient`

  * Handles HTTP calls, auth headers, JSON decoding
  * Public methods:

    * `validateToken() async throws -> Profile` (or fetch profile list and pick first)
    * `fetchStats(profileId: String, range: TimeRange) async throws -> Stats`
    * `fetchLogs(profileId: String, limit: Int) async throws -> [LogEntry]`
* `KeychainStore`

  * `saveToken`, `loadToken`, `deleteToken`
* `AppState` (Observable)

  * `authState`, `profile`, `refreshInterval`, `privacyMode`, `lastRefreshAt`, `lastError`
* `DashboardViewModel` (Observable)

  * `stats`, `logs`, `isLoading`
  * `refresh(reason:)`
* `PreferencesViewModel`

  * token validation + persistence

### Data models (Swift structs)

* `Profile`

  * `id: String`
  * `name: String`
* `Stats`

  * `range: TimeRange`
  * `requestsTotal: Int`
  * `blockedTotal: Int`
  * `blockRate: Double`
  * Optional breakdown arrays (top domains/clients)
* `LogEntry`

  * `timestamp: Date`
  * `domain: String`
  * `decision: Decision` (blocked/allowed)
  * `client: String?`
  * `device: String?`
  * Optional category/policy fields
* `TimeRange`

  * cases: `.lastHour`, `.last24Hours` (MVP default: last 24h)

## NextDNS API integration notes

* Use the official NextDNS API docs as the source of truth for:

  * Base URL
  * Auth method (header format)
  * Endpoint paths and parameters for stats/logs
* Implement:

  1. Token validation + profile retrieval
  2. Stats fetch for selected range
  3. Logs fetch with a limit (N)
* Handle pagination only if required; otherwise fetch most recent N.

Link to API docs: https://nextdns.github.io/api/

## Error handling requirements

* Map errors to user-friendly states in UI:

  * Unauthorised → “Token invalid or expired”
  * Rate limited → “Rate limited, retrying soon”
  * Offline → “Offline, showing cached data”
  * Unknown → “Something went wrong” with minimal diagnostics

## Non-functional requirements

* Startup should not block UI (load token async, show placeholders)
* Popover should open instantly; show cached content while refreshing
* Keep network usage minimal (throttle + interval)
* Avoid storing browsing history (domains) locally beyond in-memory cache (unless user opts in later)

## Implementation checklist

1. Status bar icon + SwiftUI popover
2. Preferences UI for token + refresh interval
3. KeychainStore implementation + wiring
4. NextDNSClient with auth + JSON decode
5. DashboardViewModel refresh pipeline (open/manual/timer)
6. Error states + cached display
7. Polishing: last updated time, loading indicator, basic formatting

## Definition of done

* Token can be saved/removed via Preferences and persists via Keychain
* Popover displays stats + recent logs reliably
* Refresh-on-open works with throttle
* Manual refresh works
* Polling interval works (Off/1m/5m/15m)
* App handles offline/401/429/5xx gracefully
