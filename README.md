# Football Tactics Animator

A desktop app for macOS (Flutter) for creating football/soccer tactical animations
and **exporting them as real MP4 video** — built for coaches, analysts and content creators.

## Features

### Pitch & board
- **Procedurally drawn Broadcast Green pitch** — crisp vector markings at any resolution
  (boundary, halfway line, centre circle, penalty & goal areas, penalty spots, D-arcs, corner arcs)
  with mowed stripes. No blurry background image.
- **Orientation toggle:** horizontal ↔ vertical.
- **Layout toggle:** full pitch ↔ half pitch.
- Positions are stored in real pitch metres, so toggles and export are always consistent.

### Players & ball
- **Numbered-disc tokens**, fully customizable: number/disc text, size, primary/secondary/text colors, or a photo.
- **Name labels (nameplates)** — a separate name shown beside the disc, so a player can carry both a
  number *and* a name. Full text control: font size, weight, text + background color (or no plate),
  position (below / above / left / right) and a shadow toggle — with one-click **"apply to all players."**
  Names animate in/out as they're added or removed across keyframes.
- **"Show numbers" / "Names" toggles** in the stage controls.
- **Formation presets** per team (4-4-2, 4-3-3, 4-2-3-1, 3-5-2, 4-1-4-1).
- Draggable ball (flat image).

### Drawing tools
- **Animated movement arrows** — straight and curved (either direction) — plus **oval / rectangle zones**.
- Each arrow animates during playback: pick **Draw along** or **Fade in**, and recolor or delete it.
- Arrows trace out on their own quick clock so the head **leads the run to its destination**
  ahead of the player, then keeps flowing — not glued to the mover.
- **Zones animate between keyframes too:** a zone added in the next frame **grows and fades in**,
  and one you remove **fades out** as the play moves on — it never lingers on later frames.

### Animation
- **Keyframe timeline** with thumbnails, reorderable, per-keyframe **transition duration**,
  **easing**, and **hold** (pause on a frame) — all edited on the connector between frames.
- Transport: play / pause / stop, **scrub** slider, **loop**, and **0.25×–2× speed**.
- Smooth interpolation of player and ball positions (and size) between keyframes;
  players fade in/out as they enter or leave; arrows draw themselves in.
- **Motion trails** — an optional fading streak behind movers (toggle in the stage controls, off by default).

### Editor power tools
- **Zoom & pan** the board (`⌘+` / `⌘-` / `⌘0`, scroll to pan) while keeping full edit gestures.
- **Nudge** the selection with the arrow keys (hold `⇧` for a bigger step).
- **Duplicate / copy / paste** players, arrows and zones.

### Video export (macOS)
- **Native H.264 `.mp4` export** via AVFoundation (Rec.709 color) — no external tools, no screen recording.
- Choose **720p / 1080p / 1440p / 4K**, **24 / 30 / 60 fps**, and **Standard / High / Max** quality.
- **Supersampled (2×) rendering** at sub-4K resolutions — each frame is drawn large and downscaled,
  so lines, discs, numbers and nameplates come out crisp and cleanly anti-aliased.
- Frames are rendered from a pure canvas at full resolution, so output is sharp regardless of window size.
- "Reveal in Finder" when done.

### Project & workflow
- **Autosave** — the whole project (board, names & styles, keyframes, view settings) is saved
  automatically and **restored on next launch**, so your work survives a restart. Stored in the app
  support directory on desktop and `localStorage` on the web.
- Save / open projects as `.json` (board, keyframes and view settings).
- Undo / redo, and keyboard shortcuts: `Space` play/pause, `⌘Z` / `⌘⇧Z` undo/redo,
  `⌘S` save, `⌘D` duplicate, `⌘C` / `⌘V` copy/paste, arrow keys nudge (`⇧` = larger),
  `⌘+` / `⌘-` / `⌘0` zoom, `Delete` remove selection, `Esc` deselect. (Ctrl works too, for web on Windows/Linux.)

## Getting started

```sh
flutter pub get
flutter run -d macos
```

Requires the Flutter SDK and Xcode. Saving files/video uses the macOS App Sandbox
"user-selected file" access, which is already configured in the entitlements.

### Web

A browser build is hosted on GitHub Pages: **https://ms-teja.github.io/footballTacticsAnimator/**.
Everything works in the browser except **MP4 export**, which needs native encoding — the web app
points you to the macOS download for that. Build it with
`flutter build web --release --base-href /footballTacticsAnimator/`.

## Project structure

```
lib/
  models.dart                 # data models (metre-space) + formations
  controller.dart             # app state, undo/redo, keyframes, animation engine, autosave
  export/video_exporter.dart  # Dart side of the native MP4 encoder
  export/board_renderer.dart  # pure-canvas frame renderer (thumbnails + export frames)
  utils/file_helper*.dart     # save/open/pick files (native + web implementations)
  utils/persistence*.dart     # autosave storage (app-support file on desktop, localStorage on web)
  widgets/
    pitch.dart                # PitchGeometry (metre<->screen) + procedural PitchPainter
    tactics_board.dart        # interactive board, tokens, ball, name labels, animated drawings, trails
    chrome.dart               # top bar + left tool rail
    inspector.dart            # context inspector (player/ball/arrow/zone/team)
    timeline.dart             # transport + keyframe strip
macos/Runner/MainFlutterWindow.swift  # AVFoundation H.264 encoder (method channel)
```

## License

MIT — see `LICENSE`.
