# Chlorophyll — Project Plan

> Living document. Captures the full analysis, architecture, and phased plan behind
> Chlorophyll: a native Apple Silicon rewrite of the *Greenshot for Mac* concept,
> targeting feature parity with Greenshot for Windows.
> Last updated: 2026-08-20 (after Phase 0+1).

---

## 1. Background & Motivation

### The problem

| Source | Finding |
|---|---|
| **Greenshot for Windows** (repo analysis, `greenshot` upstream) | Active (v1.3.315, Mar 2026), .NET Framework 4.8 / WinForms / GDI+ / deep Win32 coupling. Rich feature set: 4+ capture modes, 13 editor tools, effects, OCR text redaction, ~150-setting INI config, 7 plugins (Imgur, Dropbox, Box, Jira, Confluence, Office, ExternalCommand), 45 languages. **Zero code reuse possible** for macOS — value = feature spec. |
| **Greenshot for Mac** (App Store v1.2.19, installed & black-box analyzed) | Released ~June 2020, **6+ years stale**, x86_64-only (Rosetta on Apple Silicon), Swift/AppKit, 386 KB binary. Capture shells out to `/usr/sbin/screencapture` CLI (root limitation). Dead dependencies: GPUImage fork, AFNetworking, MASShortcut, ImgurSession (CocoaPods). ~12 basic editor tools; destinations: file, clipboard, printer, Mail, Imgur. English-only. Simple NSUserDefaults (8 keys). **Source is private** — not in the public repo. |
| **Modern macOS** (this M4 MacBook Air, macOS 26) | All APIs needed for parity exist natively: ScreenCaptureKit (14+), Vision (OCR), Core Image (filters), Carbon hotkeys (still functional). |

### Decisions made

| Decision | Choice | Rationale |
|---|---|---|
| Tech stack | **Native Swift 6 + SwiftUI/AppKit** | Natural evolution of the old Swift app; best Apple Silicon performance; full SCK/Vision/CI access; App Store-compatible if ever needed. |
| Identity | **Chlorophyll** (own name/logo, GPL-3.0) | Personal project; Greenshot trademark belongs to the Greenshot team. "Inspired by Greenshot" credit only. |
| Distribution | **Direct download, notarized** (Sparkle later) | No sandbox limits → all destinations/plugins possible, incl. ExternalCommand. Free like Windows Greenshot. |
| Scope | **Core parity first, plugins later** | Fastest path to a daily driver; plugin protocol keeps later work additive. |
| Baseline | **macOS 14+**, arm64 (+x86_64 if trivial) | SCScreenshotManager requires 14. |

---

## 2. Product Definition

A **menu-bar screenshot utility** (LSUIElement, no Dock icon) with:

1. **Capture**: region (interactive overlay w/ magnifier & window snapping), window (native SCK filter or screen-region fallback), fullscreen (multi-display composite), last region.
2. **Editor** (Phase 2): 13 Greenshot-parity annotation tools, selection/arrange, undo/redo, zoom, per-tool defaults.
3. **Effects** (Phase 4): border, drop shadow, torn edges, grayscale, invert, rotate/resize, auto-crop, highlight modes.
4. **Destinations**: picker, clipboard, file (templated filenames), save dialog, printer, Mail; plugin uploads (Imgur → Dropbox/Box/Jira/Confluence/Office/ExternalCommand).
5. **OCR**: capture-text-to-clipboard (Vision) + search/regex **redaction** (obfuscate text regions automatically).
6. **Config**: JSON with layered defaults (~150 keys eventually), SwiftUI settings UI parity, hotkey recorder.
7. **Editable save format**: JSON-based lossless round-trip (`.chlorophyll` files), replacing Windows' binary `.greenshot`.

**Out of scope v1**: scrolling capture (stretch: SCStream frame stitching), 45-language localization (EN+DE first, community later).

---

## 3. Architecture

```
Sources/
├── ChlorophyllCore/               (library, macOS-only, AppKit allowed)
│   ├── Capture/    CaptureEngine (SCK), ScreenGeometry (Cocoa↔CG↔SCK coords),
│   │               WindowList (CGWindowList), Permission (TCC)
│   ├── Config/     AppConfig + ConfigFileManager (layered JSON)
│   ├── Hotkeys/    HotkeyCenter (Carbon RegisterEventHotKey), HotkeyBinding
│   └── Util/       FilenameTemplate
├── ChlorophyllEditor/             (Phase 2: surface, elements, filters, mementos)
└── ChlorophyllApp/                (executable: menu bar, coordinator, UI)
    ├── UI/         RegionPicker, WindowListMenu, SettingsWindow, HotkeyRecorder,
    │               PermissionPanel, Toast
    └── AppModel, CaptureCoordinator, AppDelegate, AppMain
Scripts/make-app.sh               (CLT-compatible .app assembly + ad-hoc codesign)
```

**Key patterns** (mirroring Greenshot's proven design where sensible):
- `IDestination`-style destinations via string IDs in `config.output.destinations` → `CaptureCoordinator.deliver`.
- Coordinate spaces are bridged exclusively in `ScreenGeometry` (Cocoa bottom-left ↔ CG top-left ↔ SCK display-local top-left). All UI code stays in Cocoa space.
- Hotkeys: Carbon (only supported system-wide mechanism); recorder UI converts `NSEvent` → Carbon modifier masks (`CarbonModifiers`).

### Feature mapping (Windows → macOS)

| Greenshot Windows | Chlorophyll macOS |
|---|---|
| GDI/DWM capture, `CaptureForm` picker | ScreenCaptureKit + custom overlay |
| Win10 OCR engine | Vision `VNRecognizeTextRequest` |
| GDI+ filters / GPUImage (old Mac) | Core Image / CIFilter |
| INI config, layered | `ConfigFileManager` JSON, `decodeIfPresent` merge |
| PrintScreen hotkeys | ⌥⇧3/4/5/6 defaults (system-shortcut-safe), recorder |
| MAPI / Office COM / printer | Mail AppleScript, Office via AppleScript, `NSPrintOperation` |
| `.greenshot` binary format | JSON `.chlorophyll` format (Phase 4) |
| 45 XML languages | String catalogs, EN+DE first (Phase 6) |
| IE scrolling capture | Out of scope v1 (stretch) |

---

## 4. Phases & Status

### ✅ Phase 0 — Scaffold, build system, CI (done, 2026-08-19)

- SPM package: `ChlorophyllCore`, `ChlorophyllEditor` (placeholder), `ChlorophyllApp` (exec). Swift 6 tools, language mode 5 (upgrade to 6 later).
- `Makefile` (build/app/run/test/lint/format), `Scripts/make-app.sh` → ad-hoc signed arm64 `.app`.
- swiftlint (strict) + swiftformat configs; GitHub Actions CI (macos-15: lint → test → app artifact). **CI green.**

### ✅ Phase 1 — Capture core, hotkeys, menu bar (spike done)

- `CaptureEngine`: region/window/display capture via `SCScreenshotManager`; multi-display composite; native window filter with screen-region fallback (`windowMode: .native|.screen`).
- `RegionPicker` overlay: all displays, crosshair, dim, drag-rect + size badge, ESC cancel, click = whole display. *(Magnifier & window snapping: Phase 1.5 polish.)*
- `WindowListMenu`: on-screen windows (layer 0, sized) sorted titled-first/largest-first, top 20, pops at cursor.
- `HotkeyCenter` + defaults ⌥⇧4/5/3/6; `HotkeyRecorder` in settings (ESC cancel, ⌫ clear, ≥1 modifier enforced).
- Destinations: clipboard (PNG) + file (PNG/JPEG, template w/ counter, collision-safe, atomic write).
- `PermissionPanel` onboarding (deep-link to Settings, retry); camera shutter sound; toast w/ reveal-in-Finder.
- Settings: General/Capture/Output/Hotkeys tabs, live filename preview, folder picker.
- 14 swift-testing tests (template, config round-trip/merge/forward-compat, defaults).

**Engineering discoveries (session log):**
1. macOS 26 SDK **removed `SCStreamConfiguration.pointPixelScale`** → compute `width/height` from `NSScreen.backingScaleFactor` instead (works on 14+).
2. **CLT-only machine** (no Xcode): no `xcodebuild`; XCTest unavailable → **swift-testing** with framework-path workaround (`Makefile:test` symlinks `Testing.framework` + `lib_TestingInterop.dylib` into `.build/arm64-apple-macosx/debug`); swiftlint needs `DYLD_FRAMEWORK_PATH=/Library/Developer/CommandLineTools/usr/lib`.
3. CG↔Cocoa flip anchored at primary display height (`CGDisplayBounds(CGMainDisplayID()).height`) — verified on M4 single-display.
4. Ad-hoc signing + TCC: screen-recording permission requires **app restart** after granting (documented in onboarding panel).

### 🔲 Phase 1.5 — Picker polish (short)

- Magnifier loupe with pixel grid near cursor; window snapping/outlining under cursor (CGWindowList hit-test); arrow-key nudge/resize; Space = window mode, Enter = whole screen.
- Multi-display verification (mixed scales/arrangements).

### 🔲 Phase 2 — Editor (the big one)

- `ChlorophyllEditor` target: `EditorDocument` (elements + mementos), AppKit canvas (CALayer-backed) + SwiftUI chrome.
- Elements (Greenshot parity): rectangle, ellipse, line, arrow, freehand, text, speech bubble, step label (auto-numbering counter), highlight (area), obfuscate (blur/pixelate via Core Image), crop, image insert.
- Selection, move/resize handles, arrange (z-order), per-tool field defaults (line width, color, fill), undo/redo (`UndoManager`), zoom 25–600%, clipboard interop.
- "Open in editor" destination enabled by default.

### 🔲 Phase 3 — Remaining core destinations

- Destination picker window (Greenshot-style list, pick-then-apply or always-ask mode).
- Save-as dialog destination; printer (`NSPrintOperation`); Mail (AppleScript → Mail / `mailto:` fallback); copy-path-to-clipboard; dynamic file naming profile.

### 🔲 Phase 4 — Effects, OCR, formats

- Effects menu (border, drop shadow, torn edges, grayscale, invert, rotate, resize/canvas, auto-crop); torn edges = custom Core Image/metal kernel.
- OCR destination (Vision → text to clipboard); **redaction panel**: OCR a region, search/regex match, yellow-preview boxes, pixelize-on-apply.
- `.chlorophyll` editable JSON format (lossless, open spec).

### 🔲 Phase 5 — Plugins

- `PluginKit` in-app protocol + registry (out-of-process later if needed).
- Order: **Imgur** (OAuth via `ASWebAuthenticationSession`, history, delete links) → Dropbox → Box → Jira → Confluence → Office (AppleScript) → ExternalCommand.

### 🔲 Phase 6 — Localization, accessibility, polish

- String catalogs EN+DE; VoiceOver labels on editor handles; onboarding tour; icon set (own leaf-based branding).

### 🔲 Phase 7 — 1.0 release

- Developer ID signing + notarization (scripts ready, awaiting certificate); Sparkle appcast; DMG + zip; landing page/README; tag `v1.0.0`.

---

## 5. Testing Strategy

| Layer | Method |
|---|---|
| Unit | swift-testing (config, templates, geometry math, editor mementos, plugin models) |
| Snapshot | Filter/element rendering vs. committed fixtures |
| UI smoke | Menu/picker/editor launch on CI runner (no capture — needs TCC) |
| Manual matrix | Multi-display, scaled displays, Spaces/full-screen apps, permission-denied/restart flows, hotkey conflicts |

## 6. Risks

| Risk | Mitigation |
|---|---|
| TCC permission friction | Guided onboarding (done) + graceful degradation messages |
| SCK coordinate quirks across displays | All conversions isolated in `ScreenGeometry`; Phase 1.5 multi-display testing |
| Hotkey conflicts | ⌥⇧ defaults; registration failure → user feedback (extend: toast on failed registration) |
| Scope creep | Phase gates; plugin protocol additive |
| Single-maintainer bus factor | This document + conventional commits + CI from day one |

## 7. Immediate Next Steps

1. **User E2E test** of Phase 1 (TCC grant → ⌥⇧4 → Desktop PNG + clipboard).
2. Phase 1.5 picker polish (magnifier, snapping).
3. Phase 2 editor spike: document model + rect/arrow/text/blur first, then full tool set.
