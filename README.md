# Chlorophyll

A fast, native screenshot tool for modern Macs (Apple Silicon, macOS 14+).
Inspired by [Greenshot](https://getgreenshot.org/) for Windows — aiming for full
feature parity, rebuilt from scratch with modern macOS frameworks.

> Chlorophyll is an independent project and is not affiliated with the Greenshot
> team. Greenshot is a trademark of the Greenshot development team.

See [PLAN.md](PLAN.md) for the full background analysis, architecture,
feature-parity mapping and phased roadmap.

## Features (Phase 1 — current)

- Menu-bar app (no Dock icon), native Swift/AppKit + SwiftUI
- **Capture modes**: region (interactive overlay), window (pick from list),
  fullscreen (all displays), last region
- Global hotkeys (configurable, defaults use ⌥⇧ to avoid system conflicts)
- Export to clipboard (PNG) and/or PNG file with templated filenames
- Screen Recording permission onboarding
- JSON configuration with sensible defaults (`~/Library/Application Support/Chlorophyll/`)

## Roadmap

- [x] Phase 0 — scaffold, build system, CI
- [x] Phase 1 — ScreenCaptureKit capture core, hotkeys, menu bar, settings
- [ ] Phase 2 — full editor (annotation tools, undo/redo, effects)
- [ ] Phase 3 — destinations (picker, printer, mail, more file formats)
- [ ] Phase 4 — effects, OCR redaction (Vision), editable save format
- [ ] Phase 5 — plugins (Imgur, …)
- [ ] Phase 6 — localization, accessibility, polish
- [ ] Phase 7 — 1.0 release (notarized DMG, Sparkle updates)

## Building

Requirements: Xcode Command Line Tools (Swift 6+), macOS 14+.

```sh
make app     # build release + assemble Chlorophyll.app (ad-hoc signed)
make run     # build + launch
make test    # unit tests
make lint    # swiftlint + swiftformat checks
```

The app bundle lands in `build/Chlorophyll.app`.

**First launch:** macOS will ask for *Screen & System Audio Recording* (older
systems: *Screen Recording*) permission for Chlorophyll. The app shows an
onboarding dialog that opens the right System Settings pane for you.

## License

GPL-3.0 — see [LICENSE](LICENSE).
