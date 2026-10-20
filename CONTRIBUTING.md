# Contributing

Issues and pull requests are welcome. Run `./scripts/test.sh` before opening a PR; CI
runs the same tests and builds the app on macOS.

Halo only ships what's been checked to work. If an action depends on an app, a tool or
a keyboard shortcut, try it on a real Mac before adding it, and say how you tested it in
the PR.

## Layout

```
Sources/HaloKit/   everything testable, no UI
  Actions.swift        ActionInfo, KeyCombo, CustomAction, RingContext
  ActionCatalog.swift  Claude, text and Everywhere actions, default rings, sub-rings
  FileActions.swift    Files ring actions, convert targets, what applies to a selection
  FileOps.swift        image, PDF, video and archive operations
  Converters.swift     documents (textutil), audio (afconvert), PDF output
  FileAI.swift         Claude reading files: summaries, notes, flashcards, renames
  ClaudeClient.swift   claude CLI or Messages API
  Rewrite.swift        the prompt behind each Claude text action
  TextTools.swift      local text tools
  ProfilePresets.swift app rings and their shortcuts
  Settings.swift       settings model and storage
Sources/Halo/      the app: ring, HUD, action runner, settings window
Tests/HaloKitTests/ Swift Testing suites
```

## Adding a Claude text action

1. Add an `ActionInfo` to `claude` in `ActionCatalog.swift` with category `.ai`.
2. Add its instruction to `RewriteRequest.forAction` in `Rewrite.swift`. If the answer
   should go to the clipboard instead of replacing the selection, add its id to `copying`.
3. Add a test in `RewriteTests`.

## Adding an app ring

1. Add the app's shortcuts to `ProfilePresets.swift` with `key(...)`, using the app's
   documented defaults, not your own rebinds.
2. Add a `RingProfile` to `all` with the app's bundle identifier
   (`osascript -e 'id of app "Name"'`) and up to 10 action ids.
3. `defaultRingsOnlyUseRealActionsAndFit` checks every id exists.

## Adding a format

1. Add a `Target` to the right kind in `FileActions.targets`.
2. Handle it in `FileOps.convert`, using a converter that ships with macOS.
3. Add a conversion test in `FileOpsTests.swift` that writes a real file.

Titles go inside a ring slice, so keep them to 13 characters or fewer (a test checks).
Check new SF Symbol names exist on macOS 14.

## Releasing

Push a tag like `v1.1.0`. The Release workflow runs the tests, builds `Halo.app` with
that version and attaches `Halo.zip` to a GitHub release.
