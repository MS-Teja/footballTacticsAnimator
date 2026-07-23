# Tactics Animator — Quick Start

## 1. Set up the board
- **Left rail:** add home/away players, add the ball, and pick drawing tools.
- **Inspector (right):** with nothing selected, choose a **formation** per team, set team colors/sizes,
  and toggle **Show numbers**.
- **Over the pitch (top-right):** switch **Horizontal ↔ Vertical**, **Full ↔ Half**, and toggle numbers.

## 2. Position things
- Drag players and the ball. Click any player / ball / arrow / zone to edit it in the inspector.
- Draw a **movement arrow** (straight) or a **curved arrow**, and mark a **zone** with the tools.
  Each arrow is animated — select it to choose how it animates (**Draw along** or **Fade in**) and,
  for curved arrows, **Flip curve direction**.

## 3. Animate
1. Set the starting positions, then click **Capture** in the timeline.
2. Move players/ball, then capture another keyframe. Repeat.
3. Each keyframe shows its **duration**; click its time chip (or the connector between frames) to set
   the **transition duration**, **easing**, and a **hold** (pause on that frame). Hover a frame to
   **Update** it to the current board or **Delete** it. Drag frames to reorder; click a selected
   frame again to deselect.
4. Use the transport bar to **play/pause/stop**, **scrub**, **loop**, and change **speed**.
   Movers leave a **motion trail**, and players fade in/out when they join or leave a frame.

## 4. Export video
1. Click **Export MP4** (needs at least 2 keyframes).
2. Choose **resolution** (720p/1080p/1440p), **frame rate** (24/30/60), and **quality**
   (Standard/High/Max — higher = crisper, larger file). The dialog shows the estimated bitrate.
3. Pick where to save the `.mp4`. A progress bar shows encoding; then **Reveal in Finder**.

The video is encoded natively (H.264, Rec.709 color) — no screen recording needed.

## Shortcuts
`Space` play/pause · `⌘Z` / `⌘⇧Z` undo/redo · `⌘S` save · `⌘D` duplicate · `⌘C` / `⌘V` copy/paste ·
arrow keys nudge the selection (hold `⇧` for larger steps) · `Delete` remove · `Esc` deselect ·
`⌘+` / `⌘-` / `⌘0` zoom in / out / reset (scroll to pan when zoomed).
