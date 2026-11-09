# Morrow

A calm Markdown reader for macOS.

The application icon shows an open book under a rising sun. `MorrowIcon.png` is the original image; `Morrow.icns` is the macOS icon bundle.

## Use

Download `Morrow.pkg` from the [latest release](https://github.com/erwinbierens/Morrow/releases), then run it to install Morrow in Applications. Open the app, then choose **Open File** or press **⌘O**. Click **Edit** to change the Markdown with a live preview. **⌘S** saves your changes; **⌘⇧S** saves a copy. Select rendered text and press **⌘C** to copy it. **Paste Markdown** (⌘⇧V) renders text from your clipboard. **Copy Source** (⌘⇧C) copies the complete Markdown source. **⌘R** reloads an open file. The moon button toggles dark mode.

Task list markers `- [ ]` and `- [x]` become clickable checkboxes in the preview. Morrow also reads `- [*]` as checked. Clicking a box updates the Markdown source; save the file to keep the new state.

Morrow checks GitHub for a newer release when it opens. Use the **Updates** button to check again. If a newer release is available, Morrow downloads its installer, verifies the SHA-256 checksum published by GitHub, and opens the macOS installer. Finish installation in the installer window.

## Build

This build was compiled on macOS 27.2 with Apple Silicon. To rebuild it, install Xcode Command Line Tools and run `zsh build.sh` here. To create the installer, run `zsh package.sh`. Morrow is written in SwiftUI and uses macOS's cmark-gfm library for Markdown rendering.

This preview handles standard CommonMark. Markdown tables and local images are not yet supported. The app is signed locally for testing. The installer is unsigned and not notarized; macOS may require you to choose **Open Anyway** in Privacy & Security on first installation.

Created with [Studio Sjas Patat](https://sjaspatat.com).
