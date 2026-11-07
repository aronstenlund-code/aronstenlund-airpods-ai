// MIT License
//
// Copyright (c) 2026 Fikri Karim
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
// Source: https://github.com/fikrikarim/volocal @ b731963, Volocal/Pipeline/SentenceBuffer.swift
// Modified by Lumen, 2026-11-07: a value type that returns sentences instead of calling a closure (Swift 6
// strict concurrency); Swedish abbreviations ("t.ex.", "bl.a.", "dvs.", "osv.", "ca.", "s.k.", "kl.") and numbers
// ("3.5", "1.") are never a sentence end; used to join speech-to-text results into whole utterances (D78) rather
// than to split LLM tokens. Lines 300 characters long are cut at a word boundary (was 200).

import Foundation

/// Accumulates text and returns complete sentences. Boundaries are `!` and `?` followed by whitespace or a quote,
/// `.` followed by whitespace and an uppercase letter (or a quote), and `:` / `;` followed by whitespace.
struct SentenceBuffer: Sendable {
    private(set) var buffer = ""

    /// Maximum characters before forcing a split at the nearest word boundary.
    let maxChars: Int

    static let abbreviations: Set<String> = ["t.ex", "bl.a", "dvs", "osv", "ca", "s.k", "kl", "nr", "st", "resp", "m.m",
                                             "o.s.v", "d.v.s", "fr.o.m", "t.o.m", "e.d", "p.g.a", "pga", "jfr", "ex", "dr", "mr"]

    init(maxChars: Int = 300) {
        self.maxChars = maxChars
    }

    var isEmpty: Bool { buffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Adds text; returns the sentences it completed.
    mutating func append(_ text: String) -> [String] {
        buffer += text
        var sentences: [String] = []

        while let range = findSentenceBoundary() {
            let sentence = String(buffer[buffer.startIndex...range.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                sentences.append(sentence)
            }
            let nextIndex = range.upperBound
            if nextIndex < buffer.endIndex {
                buffer = String(buffer[nextIndex...]).trimmingCharacters(in: .whitespaces)
            } else {
                buffer = ""
            }
        }

        if buffer.count > maxChars, let forced = forceSplitAtWordBoundary() {
            sentences.append(forced)
        }
        return sentences
    }

    /// Returns what is left (end of the utterance) and empties the buffer.
    mutating func flush() -> String? {
        let remaining = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        buffer = ""
        return remaining.isEmpty ? nil : remaining
    }

    mutating func reset() {
        buffer = ""
    }

    // MARK: - Private

    /// The range of the boundary character (lowerBound) and the index after it (upperBound).
    private func findSentenceBoundary() -> Range<String.Index>? {
        for i in buffer.indices {
            let char = buffer[i]
            let nextIndex = buffer.index(after: i)
            guard nextIndex < buffer.endIndex else { continue }
            let nextChar = buffer[nextIndex]

            // Primary boundaries: ! and ?
            if char == "!" || char == "?" {
                if nextChar == " " || nextChar == "\n" || nextChar == "\"" || nextChar == "\u{201D}" {
                    return i..<nextIndex
                }
            }

            // Period: only before an uppercase letter, and never after an abbreviation or a number.
            if char == "." {
                if nextChar == " " || nextChar == "\n" {
                    let afterSpace = buffer.index(after: nextIndex)
                    if afterSpace < buffer.endIndex, buffer[afterSpace].isUppercase, !endsWithAbbreviationOrNumber(before: i) {
                        return i..<nextIndex
                    }
                } else if nextChar == "\"" || nextChar == "\u{201D}" {
                    return i..<nextIndex
                }
            }

            // Secondary boundaries: : and ;
            if char == ":" || char == ";" {
                if nextChar == " " || nextChar == "\n" {
                    return i..<nextIndex
                }
            }
        }
        return nil
    }

    /// The word before the period at `index`: "t.ex", "kl", "3", "1".
    private func endsWithAbbreviationOrNumber(before index: String.Index) -> Bool {
        let head = buffer[buffer.startIndex..<index]
        let word = head.split(separator: " ").last.map { String($0).lowercased() } ?? ""
        if word.isEmpty { return false }
        if word.allSatisfy({ $0.isNumber || $0 == "," || $0 == "." }) { return true }
        return Self.abbreviations.contains(word)
    }

    /// Force a split at the nearest word boundary when the buffer is too long.
    private mutating func forceSplitAtWordBoundary() -> String? {
        var splitIndex = buffer.startIndex
        for i in buffer.indices {
            if buffer.distance(from: buffer.startIndex, to: i) >= maxChars { break }
            if buffer[i] == " " {
                splitIndex = i
            }
        }
        guard splitIndex > buffer.startIndex else { return nil }
        let sentence = String(buffer[buffer.startIndex..<splitIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        let nextIndex = buffer.index(after: splitIndex)
        buffer = nextIndex < buffer.endIndex ? String(buffer[nextIndex...]) : ""
        return sentence.isEmpty ? nil : sentence
    }
}
