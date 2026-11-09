# Morrow

A calm Markdown reader for macOS.

The application icon shows an open book under a rising sun. `MorrowIcon.png` is the original image; `Morrow.icns` is the macOS icon bundle.

## Use

If you have `Morrow.pkg`, run it to install Morrow in Applications. Open the app, then choose **Open File** or press **⌘O**. Select rendered text and press **⌘C** to copy it. **Paste Markdown** (⌘V) renders text from your clipboard. **Copy Source** (⌘⇧C) copies the complete Markdown source. **⌘R** reloads an open file. The moon button toggles dark mode.

## Build

This build was compiled on macOS 27.2 with Apple Silicon. To rebuild it, install Xcode Command Line Tools and run `zsh build.sh` here. To create the installer, run `zsh package.sh`. Morrow is written in SwiftUI and uses macOS's cmark-gfm library for Markdown rendering.

This first version handles standard CommonMark. Markdown tables and local images are not yet supported. The app is signed locally for testing. The installer is unsigned and not notarized; macOS may require you to choose **Open Anyway** in Privacy & Security on first installation.
