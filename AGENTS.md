# Repository Guidelines

## Project Structure & Module Organization
- `Sources/NextDNSPeek/` contains the macOS app source code.
  - `App/`: app entry points, status bar host, and window controllers.
  - `Models/`: lightweight Swift data models (e.g., `Profile`, `Stats`).
  - `Services/`: API client, keychain, and settings storage.
  - `ViewModels/`: observable state and refresh logic.
  - `Views/`: SwiftUI views for the popover and preferences.
- `NextDNSPeek.xcodeproj/` is the Xcode project.
- `NextDNSPeek/Info.plist` holds app metadata (menu bar app with `LSUIElement`).
- `Changelog/` stores one markdown file per change.

## Build, Test, and Development Commands
- Build (Debug):
  - `xcodebuild -project NextDNSPeek.xcodeproj -scheme NextDNSPeek -configuration Debug -derivedDataPath build`
- Run locally:
  - `open "build/Build/Products/Debug/NextDNS Peek.app"`
- There is currently no automated test suite.
- Create a new build every time code has been changed.

## Coding Style & Naming Conventions
- Swift uses 2-space indentation in this repo.
- Use SwiftUI conventions (`View` structs, `@StateObject` / `@ObservedObject` where appropriate).
- Filenames and type names follow Swift naming (PascalCase types, camelCase properties).
- Prefer concise, descriptive names (e.g., `DashboardViewModel`, `KeychainStore`).

## Testing Guidelines
- No test frameworks are configured yet.
- If you add tests, place them in a new `Tests/` directory and document how to run them here.

## Commit & Pull Request Guidelines
- No commit message conventions are documented in this repository.
- PRs should include a short description of changes and any UI screenshots for view changes.

## Agent-Specific Instructions
- Maintain a `Changelog/` entry per change (new file each time).
- For every change you make, create a new markdown file in `Changelog/` that describes the update.
- Include code snippets in each changelog entry to show relevant context for the change.
- Keep the app menu-bar friendly; avoid adding dock windows unless for debugging.

## Change Summary

- Updated: `AGENTS.md`, `README.md`, `.github/workflows/release.yml`.
- Created: None.
- Deleted: `ExportOptions.plist`.

Simplified GitHub Action workflow to use ad-hoc signing for personal and technical audience use, removing the requirement for Apple Developer Program membership. Added installation instructions to README.
- Add a small description of what is added using code snippets. Example:

```markdown
The user asked for a new feature to log changes. Added a `Changelog/` directory and instructions for maintaining per-change markdown files.

Code updated:
<Add code updated details here>

Code created:
<Add code created details here>

Code deleted:
<Add code deleted details here>
```

- Use date YYYY-MM-DD.md as the file name. If it already exists, append to the existing file.

## NextDNS API

- Refer to the [NextDNS API documentation](https://nextdns.io/docs/api) for details on available endpoints and usage.