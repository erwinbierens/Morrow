import Foundation

@_silgen_name("cmark_markdown_to_html")
private func cmarkMarkdownToHTML(
    _ text: UnsafePointer<CChar>,
    _ length: Int,
    _ options: Int32
) -> UnsafeMutablePointer<CChar>?

private enum TaskSyntax {
    // Standard task lists use [ ] and [x]. [*] is accepted as a checked marker too.
    static let marker = try! NSRegularExpression(
        pattern: #"^\s*(?:[-+*]|\d+[.)])\s+(\[([ xX*])\])(?=\s|$)"#
    )
}

private func taskMarker(in line: String) -> (range: Range<String.Index>, checked: Bool)? {
    let range = NSRange(line.startIndex..<line.endIndex, in: line)
    guard let match = TaskSyntax.marker.firstMatch(in: line, range: range),
          let markerRange = Range(match.range(at: 1), in: line),
          let stateRange = Range(match.range(at: 2), in: line)
    else { return nil }
    return (markerRange, line[stateRange] != " ")
}

private struct TaskMatch {
    let lineIndex: Int
    let range: Range<String.Index>
    let checked: Bool
}

private func taskMatches(in lines: [String]) -> [TaskMatch] {
    var matches: [TaskMatch] = []
    var fenceCharacter: Character?
    var fenceLength = 0

    for (lineIndex, line) in lines.enumerated() {
        let indentation = line.prefix(while: { $0 == " " }).count
        if indentation <= 3 {
            let content = line.dropFirst(indentation)
            if let first = content.first, first == "`" || first == "~" {
                let runLength = content.prefix(while: { $0 == first }).count
                if runLength >= 3 {
                    if fenceCharacter == nil {
                        fenceCharacter = first
                        fenceLength = runLength
                    } else if fenceCharacter == first && runLength >= fenceLength {
                        fenceCharacter = nil
                        fenceLength = 0
                    }
                    continue
                }
            }
        }
        guard fenceCharacter == nil, let marker = taskMarker(in: line) else { continue }
        matches.append(TaskMatch(lineIndex: lineIndex, range: marker.range, checked: marker.checked))
    }
    return matches
}

func toggledMarkdownTask(in markdown: String, at taskIndex: Int) -> String? {
    guard taskIndex >= 0 else { return nil }
    var lines = markdown.components(separatedBy: "\n")
    let matches = taskMatches(in: lines)
    guard matches.indices.contains(taskIndex) else { return nil }
    let task = matches[taskIndex]
    lines[task.lineIndex].replaceSubrange(task.range, with: task.checked ? "[ ]" : "[x]")
    return lines.joined(separator: "\n")
}

func renderMarkdown(_ markdown: String) -> String {
    let nonce = String(markdown.hashValue.magnitude, radix: 16)
    var lines = markdown.components(separatedBy: "\n")
    var taskTokens: [(token: String, checked: Bool)] = []

    for marker in taskMatches(in: lines) {
        let token = "MORROWTASK\(nonce)\(taskTokens.count)END"
        lines[marker.lineIndex].replaceSubrange(marker.range, with: token)
        taskTokens.append((token, marker.checked))
    }

    let prepared = lines.joined(separator: "\n")
    guard let rendered = prepared.withCString({ pointer in
        cmarkMarkdownToHTML(pointer, prepared.utf8.count, 0)
    }) else {
        return "<p>This document could not be rendered.</p>"
    }
    defer { free(rendered) }

    var html = String(cString: rendered)
    for (index, task) in taskTokens.enumerated() {
        let state = task.checked ? "true" : "false"
        let mark = task.checked ? "&#10003;" : "&nbsp;"
        let link = "<a class=\"taskbox\" role=\"checkbox\" aria-checked=\"\(state)\" href=\"morrow-task://toggle/\(index)\" title=\"Toggle task\">\(mark)</a>"
        html = html.replacingOccurrences(of: task.token, with: link)
    }
    return html
}
