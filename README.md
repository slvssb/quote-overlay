# Quote Overlay

Menu bar app that shows a quote (text or a picture) on top of your wallpaper,
without changing the wallpaper. It sits behind every window, ignores clicks, and
is hidden in Mission Control.

## Requirements

macOS 14 or later and the Swift toolchain (Xcode or the Command Line Tools).

## Install

From the repo root:

    ./scripts/install.sh

Builds the app, copies it to `~/Applications/QuoteOverlay.app` and launches it.
On first launch the installed copy turns on Launch at Login, so it comes back
after a restart (turn it off from the menu bar). Re-run the script after changes. The script locates the repo itself, so it can
also be run from any directory as `<path-to-repo>/scripts/install.sh`.

## Dev build

From the repo root:

    ./scripts/bundle.sh
    open QuoteOverlay.app

## Use

- Menu bar icon (quote bubble): Next/Previous quote, Show Quote, Arrange on Screen…,
  Settings…, Launch at Login, Quit.
- **Arrange on Screen…** (⌘A): the quote floats above windows; drag it anywhere,
  drag the corner dot to resize, then press Done / Return / Esc. It snaps to the
  screen's horizontal and vertical center lines (shown as yellow guides).
- **Settings → Quotes**: add (+) / remove (−) quotes. For a picture quote use
  *Choose Image…* or *Paste Image* (e.g. after copying a screenshot with ⌃⇧⌘4).
  Pictures are capped to a fraction of the screen (Appearance → Pictures → Max size).
- **Settings → Appearance**: position, rotation interval, shuffle, picture size,
  text size, opacity, serif font, dark text.
  - A ↺ arrow appears next to any setting you've changed; click it to reset just
    that setting.
  - **Reset All Settings…** restores every setting at once. Quotes and pictures
    are kept.

Data lives in `~/Library/Application Support/QuoteOverlay/` (quotes.json + Images/).

## How the overlay works

`OverlayWindow` is a borderless, transparent, click-through window at
`desktopWindow + 1` level (above wallpaper, below desktop icons and apps) with
collection behavior `.canJoinAllSpaces, .transient, .ignoresCycle`. `.transient`
is what makes Mission Control hide it.
