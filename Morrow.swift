import AppKit
import Foundation
import SwiftUI
import WebKit

@MainActor
final class ReaderModel: ObservableObject {
    @Published private(set) var fileURL: URL?
    @Published private(set) var markdown = """
        # Welcome to Morrow

        A quiet place to read your `.md` files.

        ## Get started

        - Choose **Open File** or press **⌘O**.
        - Select text and press **⌘C** to copy it.
        - Use **Paste Markdown** to preview text from your clipboard.
        - Click **Edit** to change the source and see a live preview.
        - Click a task box to check it off, then press **⌘S** to save.
        - Switch between light and dark mode in the top right.

        - [ ] Try a task
        - [x] Enjoy the result

        > A little more room to think, one page at a time.

        ```rust
        fn main() {
            println!("Happy reading!");
        }
        ```
        """
    @Published var isDark = false
    @Published var isEditing = false
    @Published var errorMessage: String?
    @Published private(set) var isPasted = false
    @Published private(set) var isUntitled = false
    @Published private(set) var isDirty = false

    var title: String {
        let name = fileURL?.lastPathComponent ?? (isUntitled ? "Untitled.md" : isPasted ? "Pasted Markdown" : "Welcome.md")
        return name + (isDirty ? " •" : "")
    }

    var pageHTML: String {
        let foreground = isDark ? "#e8e9ed" : "#252934"
        let muted = isDark ? "#a7adb8" : "#687180"
        let background = isDark ? "#17191e" : "#f5f3ee"
        let paper = isDark ? "#202329" : "#fffdf9"
        let border = isDark ? "#363b45" : "#e8e3da"
        let code = isDark ? "#2b3038" : "#f3f1ec"
        let accent = isDark ? "#a8c7ff" : "#285c9a"

        return """
        <!doctype html><html lang="en"><head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src https: data:; style-src 'unsafe-inline'">
        <style>
        :root { color-scheme: \(isDark ? "dark" : "light"); }
        * { box-sizing: border-box; }
        html { background: \(background); }
        body { margin: 0; padding: 36px 30px 100px; color: \(foreground); background: \(background);
               font: 17px/1.78 -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif; }
        article { max-width: 790px; min-height: 80vh; margin: 0 auto; padding: 54px 66px 80px;
                  background: \(paper); border: 1px solid \(border); border-radius: 16px;
                  box-shadow: 0 12px 42px rgba(0,0,0,\(isDark ? "0.12" : "0.045")); }
        h1, h2, h3, h4, h5, h6 { line-height: 1.24; letter-spacing: -0.025em; margin: 1.8em 0 .55em; }
        h1 { font-size: 2.3em; margin-top: 0; padding-bottom: .35em; border-bottom: 1px solid \(border); }
        h2 { font-size: 1.65em; padding-bottom: .25em; border-bottom: 1px solid \(border); }
        h3 { font-size: 1.25em; }
        p { margin: 0 0 1.15em; }
        a { color: \(accent); text-decoration: none; border-bottom: 1px solid currentColor; }
        a:hover { opacity: .75; }
        strong { font-weight: 650; }
        ul, ol { padding-left: 1.55em; margin: 0 0 1.3em; }
        li { padding-left: .15em; margin: .28em 0; }
        li > p { margin: .3em 0; }
        .taskbox { display: inline-flex; width: 1.15em; height: 1.15em; margin-right: .35em;
                   align-items: center; justify-content: center; vertical-align: -0.12em;
                   border: 1.5px solid \(accent); border-radius: 4px; color: \(paper);
                   background: transparent; font: 600 .8em/1 -apple-system, sans-serif;
                   text-decoration: none; cursor: pointer; }
        .taskbox[aria-checked="true"] { background: \(accent); }
        .taskbox:hover { box-shadow: 0 0 0 3px \(border); opacity: 1; }
        blockquote { margin: 1.6em 0; padding: .1em 1.3em; color: \(muted);
                     border-left: 3px solid \(accent); background: \(code); border-radius: 0 8px 8px 0; }
        blockquote p { margin: .7em 0; }
        code, pre { font: .88em/1.55 ui-monospace, SFMono-Regular, Menlo, monospace; }
        :not(pre) > code { padding: .15em .35em; background: \(code); border-radius: 5px; }
        pre { overflow: auto; padding: 1.25em 1.4em; background: \(code); border: 1px solid \(border); border-radius: 10px; }
        pre code { padding: 0; background: transparent; }
        hr { border: 0; border-top: 1px solid \(border); margin: 2.3em 0; }
        img { max-width: 100%; height: auto; border-radius: 8px; }
        table { display: block; overflow-x: auto; border-collapse: collapse; width: 100%; margin: 1.5em 0; }
        th, td { border: 1px solid \(border); padding: .5em .8em; text-align: left; }
        th { background: \(code); }
        @media (max-width: 680px) { body { padding: 12px 10px 50px; } article { padding: 32px 26px 50px; } }
        </style></head><body><article>\(renderMarkdown(markdown))</article></body></html>
        """
    }

    func open() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "md")!, .init(filenameExtension: "markdown")!]
        panel.allowsOtherFileTypes = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        load(url)
    }

    func load(_ url: URL) {
        guard confirmDiscardChanges() else { return }
        do {
            markdown = try String(contentsOf: url, encoding: .utf8)
            fileURL = url
            isPasted = false
            isUntitled = false
            isDirty = false
            errorMessage = nil
        } catch {
            errorMessage = "Could not open file: \(error.localizedDescription)"
        }
    }

    func pasteMarkdown() {
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
            errorMessage = "The clipboard does not contain text."
            return
        }
        guard confirmDiscardChanges() else { return }
        markdown = text
        fileURL = nil
        isPasted = true
        isUntitled = false
        isDirty = true
        errorMessage = nil
    }

    func editMarkdown(_ text: String) {
        guard markdown != text else { return }
        markdown = text
        isDirty = true
    }

    func toggleTask(at index: Int) {
        guard let updated = toggledMarkdownTask(in: markdown, at: index) else { return }
        editMarkdown(updated)
    }

    func newDocument() {
        guard confirmDiscardChanges() else { return }
        markdown = "# Untitled\n\n- [ ] First task\n"
        fileURL = nil
        isPasted = false
        isUntitled = true
        isDirty = true
        errorMessage = nil
    }

    @discardableResult
    func save() -> Bool {
        guard let fileURL else { return saveAs() }
        return write(to: fileURL)
    }

    @discardableResult
    func saveAs() -> Bool {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "md")!]
        panel.nameFieldStringValue = fileURL?.lastPathComponent ?? "Untitled.md"
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        return write(to: url)
    }

    private func write(to url: URL) -> Bool {
        do {
            try markdown.write(to: url, atomically: true, encoding: .utf8)
            fileURL = url
            isPasted = false
            isUntitled = false
            isDirty = false
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Could not save file: \(error.localizedDescription)"
            return false
        }
    }

    private func confirmDiscardChanges() -> Bool {
        guard isDirty else { return true }
        let alert = NSAlert()
        alert.messageText = "Save changes to \(title.replacingOccurrences(of: " •", with: ""))?"
        alert.informativeText = "Your changes will be lost if you don't save them."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don't Save")
        alert.addButton(withTitle: "Cancel")
        switch alert.runModal() {
        case .alertFirstButtonReturn: return save()
        case .alertSecondButtonReturn: return true
        default: return false
        }
    }

    func copyMarkdownSource() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdown, forType: .string)
    }

    func reload() {
        if let fileURL { load(fileURL) }
    }
}

private struct MarkdownWebView: NSViewRepresentable {
    let html: String
    let onToggleTask: (Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onToggleTask: onToggleTask) }

    func makeNSView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.navigationDelegate = context.coordinator
        view.setValue(false, forKey: "drawsBackground")
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        context.coordinator.onToggleTask = onToggleTask
        guard context.coordinator.lastHTML != html else { return }
        context.coordinator.lastHTML = html
        view.loadHTMLString(html, baseURL: nil)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var lastHTML = ""
        var onToggleTask: (Int) -> Void

        init(onToggleTask: @escaping (Int) -> Void) {
            self.onToggleTask = onToggleTask
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                if url.scheme == "morrow-task", let index = Int(url.lastPathComponent) {
                    onToggleTask(index)
                    decisionHandler(.cancel)
                    return
                }
                if ["https", "http"].contains(url.scheme?.lowercased() ?? "") {
                    NSWorkspace.shared.open(url)
                }
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}

private struct ReaderView: View {
    @ObservedObject var model: ReaderModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Morrow").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                    Text(model.title).font(.system(size: 17, weight: .semibold)).lineLimit(1)
                }
                Spacer()
                if model.fileURL != nil {
                    Button(action: model.reload) { Label("Reload", systemImage: "arrow.clockwise") }
                }
                Button(action: model.open) { Label("Open File", systemImage: "folder") }
                    .keyboardShortcut("o", modifiers: .command)
                Button(action: model.pasteMarkdown) { Label("Paste Markdown", systemImage: "doc.on.clipboard") }
                    .keyboardShortcut("v", modifiers: [.command, .shift])
                Button(action: model.copyMarkdownSource) { Label("Copy Source", systemImage: "doc.on.doc") }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                Button {
                    model.isEditing.toggle()
                } label: {
                    Label(model.isEditing ? "Preview" : "Edit", systemImage: model.isEditing ? "eye" : "square.and.pencil")
                }
                Button { _ = model.save() } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .disabled(!model.isDirty)
                Button {
                    model.isDark.toggle()
                } label: {
                    Image(systemName: model.isDark ? "sun.max" : "moon")
                }
                .help(model.isDark ? "Light mode" : "Dark mode")
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 13)
            Divider()
            if model.isEditing {
                HSplitView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("MARKDOWN SOURCE")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 11)
                        Divider()
                        TextEditor(text: Binding(
                            get: { model.markdown },
                            set: { model.editMarkdown($0) }
                        ))
                        .font(.system(size: 14, design: .monospaced))
                        .padding(12)
                    }
                    .frame(minWidth: 310)
                    MarkdownWebView(html: model.pageHTML, onToggleTask: model.toggleTask)
                        .frame(minWidth: 400)
                }
            } else {
                MarkdownWebView(html: model.pageHTML, onToggleTask: model.toggleTask)
            }
        }
        .frame(minWidth: 900, minHeight: 520)
        .preferredColorScheme(model.isDark ? .dark : .light)
        .alert("Morrow", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}

@main
struct MorrowApp: App {
    @StateObject private var model = ReaderModel()

    var body: some Scene {
        WindowGroup {
            ReaderView(model: model)
                .onOpenURL { model.load($0) }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Document", action: model.newDocument)
                    .keyboardShortcut("n", modifiers: .command)
                Button("Open File…", action: model.open)
                    .keyboardShortcut("o", modifiers: .command)
                Button("Save") { _ = model.save() }
                    .keyboardShortcut("s", modifiers: .command)
                Button("Save As…") { _ = model.saveAs() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                Divider()
                Button("Reload", action: model.reload)
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(model.fileURL == nil)
            }
        }
        .defaultSize(width: 1100, height: 760)
    }
}
