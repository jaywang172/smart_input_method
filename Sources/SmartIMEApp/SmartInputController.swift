import Cocoa
import InputMethodKit
import SmartIMECore

class SmartInputController: IMKInputController {
    
    private let logger = FileLogger()
    private let engine = InputEngine()
    private let candidateWindow = CandidateWindowController()
    
    /// 已確認的組字緩衝區（連續輸入模式用）
    private var committedBuffer: [String] = []
    /// 目前是否在選字模式
    private var isSelectingCandidate: Bool = false
    
    // MARK: - Helper Methods
    
    private func containsCJK(_ text: String) -> Bool {
        return text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value) ||
            (0x3400...0x4DBF).contains(scalar.value)
        }
    }

    private func isASCIIWord(_ text: String) -> Bool {
        return !text.isEmpty && text.allSatisfy { $0.isASCII && $0.isLetter }
    }

    private func hasBopomofoToneOrKeyHint(_ text: String) -> Bool {
        let bopomofoHintChars: Set<Character> = ["6", "3", "4", "7", "1", "2", "5", "8", "9", "0", "-", ";", ",", ".", "/", " "]
        return text.contains { bopomofoHintChars.contains($0) }
    }
    
    // MARK: - Candidate Management
    
    /// 更新候選字視窗
    private func updateCandidateWindow(_ client: IMKTextInput) {
        let candidates = engine.getCandidates()
        guard !candidates.isEmpty else {
            candidateWindow.hide()
            return
        }
        
        // 取得游標位置
        var cursorRect = NSRect.zero
        client.attributes(forCharacterIndex: 0, lineHeightRectangle: &cursorRect)
        
        // 如果取不到位置，使用滑鼠位置作為 fallback
        if cursorRect == .zero {
            let mouseLocation = NSEvent.mouseLocation
            cursorRect = NSRect(x: mouseLocation.x, y: mouseLocation.y, width: 0, height: 20)
        }
        
        let candidateTexts = candidates.prefix(9).map { $0.text }
        
        candidateWindow.show(candidates: Array(candidateTexts), cursorRect: cursorRect) { [weak self] index in
            self?.commitCandidate(at: index, client: client)
        }
    }
    
    /// 提交指定索引的候選字
    private func commitCandidate(at index: Int, client: IMKTextInput) {
        let candidates = engine.getCandidates()
        guard index < candidates.count else { return }
        
        let selected = candidates[index]
        logger.log("Commit candidate[\(index)]: \(selected.text)")
        
        // 組合已確認緩衝區 + 新選字
        let fullText: String
        if committedBuffer.isEmpty {
            fullText = selected.text
        } else {
            fullText = committedBuffer.joined() + selected.text
        }
        
        client.insertText(fullText, replacementRange: NSRange(location: NSNotFound, length: 0))
        client.setMarkedText("", selectionRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        
        // 更新引擎上下文
        engine.selectCandidate(at: index)
        
        // 清空狀態
        engine.clearInput()
        committedBuffer.removeAll()
        isSelectingCandidate = false
        candidateWindow.hide()
    }

    /// 提交最佳候選字
    private func commitBestCandidate(_ client: IMKTextInput) {
        let rawInput = engine.currentInput
        guard !rawInput.isEmpty else { return }

        let candidates = engine.getCandidates()
        let chineseCandidates = candidates.filter { $0.source == .bopomofoConversion && containsCJK($0.text) }
        let bestChinese = chineseCandidates.max { $0.score < $1.score }
        let englishCandidates = candidates.filter { $0.source == .englishCompletion }
        let exactEnglish = englishCandidates.first { $0.text.lowercased() == rawInput.lowercased() }

        let commitText: String
        let reason: String

        if hasBopomofoToneOrKeyHint(rawInput), let chinese = bestChinese {
            commitText = chinese.text
            reason = "bopomofo_hint"
        } else if isASCIIWord(rawInput), let english = exactEnglish {
            if let chinese = bestChinese, chinese.score > english.score * 1.8 {
                commitText = chinese.text
                reason = "chinese_score_dominates"
            } else {
                commitText = english.text
                reason = "exact_english"
            }
        } else if let chinese = bestChinese {
            commitText = chinese.text
            reason = "best_chinese"
        } else if let english = exactEnglish {
            commitText = english.text
            reason = "fallback_exact_english"
        } else {
            commitText = rawInput
            reason = "raw_input"
        }

        logger.log("Commit best: raw=\(rawInput), commit=\(commitText), reason=\(reason)")
        
        // 組合已確認緩衝區
        let fullText: String
        if committedBuffer.isEmpty {
            fullText = commitText
        } else {
            fullText = committedBuffer.joined() + commitText
        }
        
        client.insertText(fullText, replacementRange: NSRange(location: NSNotFound, length: 0))
        client.setMarkedText("", selectionRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        engine.clearInput()
        committedBuffer.removeAll()
        isSelectingCandidate = false
        candidateWindow.hide()
    }
    
    /// 將當前最佳候選字加入已確認緩衝區，繼續輸入
    private func appendBestToBuffer(_ client: IMKTextInput) {
        let candidates = engine.getCandidates()
        let chineseCandidates = candidates.filter { $0.source == .bopomofoConversion && containsCJK($0.text) }
        
        if let best = chineseCandidates.max(by: { $0.score < $1.score }) {
            committedBuffer.append(best.text)
            logger.log("Append to buffer: \(best.text), buffer=\(committedBuffer)")
            
            // 更新引擎上下文
            if let idx = candidates.firstIndex(where: { $0.text == best.text }) {
                engine.selectCandidate(at: idx)
            }
        }
        
        engine.clearInput()
        
        // 更新 marked text 顯示已確認的字
        let display = committedBuffer.joined()
        client.setMarkedText(display, selectionRange: NSRange(location: display.count, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        candidateWindow.hide()
    }
    
    // MARK: - IMKInputController Overrides
    
    override func activateServer(_ sender: Any!) {
        logger.log("SmartInputController activated")
        engine.reset()
        committedBuffer.removeAll()
        isSelectingCandidate = false
        super.activateServer(sender)
    }
    
    override func deactivateServer(_ sender: Any!) {
        logger.log("SmartInputController deactivated")
        if !engine.currentInput.isEmpty || !committedBuffer.isEmpty {
            commitComposition(sender)
        }
        candidateWindow.hide()
        super.deactivateServer(sender)
    }
    
    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event = event, let client = sender as? IMKTextInput else { return false }
        
        guard event.type == .keyDown else { return false }
        
        let keyCode = event.keyCode
        let hasBuffer = !engine.currentInput.isEmpty || !committedBuffer.isEmpty
        
        // ──────────────────────────────────────────────
        // 1. Escape：取消輸入 / 關閉候選窗
        // ──────────────────────────────────────────────
        if keyCode == 53 { // Escape
            if hasBuffer {
                logger.log("Escape pressed, clearing all")
                engine.clearInput()
                committedBuffer.removeAll()
                isSelectingCandidate = false
                candidateWindow.hide()
                client.setMarkedText("", selectionRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
                return true
            }
            return false
        }
        
        // ──────────────────────────────────────────────
        // 2. 方向鍵：在候選字間移動
        // ──────────────────────────────────────────────
        if keyCode == 125 { // Down
            if candidateWindow.isVisible {
                candidateWindow.moveSelection(by: 1)
                return true
            } else if !engine.currentInput.isEmpty {
                // 開啟候選字視窗
                isSelectingCandidate = true
                updateCandidateWindow(client)
                return true
            }
            return false
        }
        
        if keyCode == 126 { // Up
            if candidateWindow.isVisible {
                candidateWindow.moveSelection(by: -1)
                return true
            }
            return false
        }
        
        // ──────────────────────────────────────────────
        // 3. 數字鍵 1-9：直接選字（僅在候選窗開啟時）
        // ──────────────────────────────────────────────
        if candidateWindow.isVisible, let chars = event.characters, chars.count == 1 {
            if let digit = chars.first, digit >= "1" && digit <= "9" {
                let number = Int(String(digit))!
                if candidateWindow.selectByNumber(number) {
                    return true
                }
            }
        }
        
        // ──────────────────────────────────────────────
        // 4. Backspace：刪除
        // ──────────────────────────────────────────────
        if keyCode == 51 { // Backspace / Delete
            if !engine.currentInput.isEmpty {
                logger.log("Backspace pressed, current input: \(engine.currentInput)")
                _ = engine.deleteLastCharacter()
                
                if !engine.currentInput.isEmpty {
                    let display = (committedBuffer.joined()) + engine.compositionString
                    logger.log("Updating mark text: \(display)")
                    client.setMarkedText(display, selectionRange: NSRange(location: display.count, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
                    updateCandidateWindow(client)
                } else if !committedBuffer.isEmpty {
                    // 輸入緩衝清空，但已確認緩衝還有字
                    let display = committedBuffer.joined()
                    client.setMarkedText(display, selectionRange: NSRange(location: display.count, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
                    candidateWindow.hide()
                } else {
                    logger.log("Input cleared")
                    client.setMarkedText("", selectionRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
                    candidateWindow.hide()
                }
                return true
            } else if !committedBuffer.isEmpty {
                // 刪除已確認緩衝區的最後一個字
                committedBuffer.removeLast()
                if committedBuffer.isEmpty {
                    client.setMarkedText("", selectionRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
                } else {
                    let display = committedBuffer.joined()
                    client.setMarkedText(display, selectionRange: NSRange(location: display.count, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
                }
                return true
            }
            return false
        }
        
        // ──────────────────────────────────────────────
        // 5. Enter：提交
        // ──────────────────────────────────────────────
        if keyCode == 36 { // Enter
            if candidateWindow.isVisible {
                // 選字模式：提交當前選中的候選
                candidateWindow.confirmSelection()
                return true
            }
            if hasBuffer {
                logger.log("Enter pressed, committing")
                commitBestCandidate(client)
                return true
            }
            return false
        }
        
        // ──────────────────────────────────────────────
        // 6. Space：提交最佳候選
        // ──────────────────────────────────────────────
        if keyCode == 49 { // Space
            if candidateWindow.isVisible {
                candidateWindow.confirmSelection()
                return true
            }
            if hasBuffer {
                logger.log("Space pressed, committing best candidate")
                commitBestCandidate(client)
                return true
            }
            return false
        }
        
        // ──────────────────────────────────────────────
        // 7. Tab：將當前最佳候選加入緩衝，繼續輸入
        // ──────────────────────────────────────────────
        if keyCode == 48 { // Tab
            if !engine.currentInput.isEmpty {
                let candidates = engine.getCandidates()
                let hasChinese = candidates.contains { containsCJK($0.text) }
                if hasChinese {
                    logger.log("Tab pressed, append to buffer and continue")
                    appendBestToBuffer(client)
                    return true
                }
            }
            return false
        }
        
        // ──────────────────────────────────────────────
        // 8. 一般字元處理
        // ──────────────────────────────────────────────
        if let chars = event.characters, !chars.isEmpty,
           let scalar = chars.unicodeScalars.first,
           scalar.isASCII {
            
            let char = Character(scalar)
            let punctuationChars: Set<Character> = [".", ",", "!", "?", ";", ":", "'", "\"", "(", ")", "[", "]", "{", "}", "<", ">", "-", "/", "\\"]

            // 標點符號：先提交再輸出標點
            if punctuationChars.contains(char) {
                if hasBuffer {
                    logger.log("Punctuation pressed, committing best candidate: \(char)")
                    commitBestCandidate(client)
                    client.insertText(String(char), replacementRange: NSRange(location: NSNotFound, length: 0))
                    return true
                }
                return false
            }

            // 字母和數字
            if char.isLetter || char.isNumber {
                // 如果候選窗開啟且是數字鍵（已在上面處理），這裡不會到達
                // 關閉候選窗進入一般輸入模式
                if candidateWindow.isVisible && !isSelectingCandidate {
                    candidateWindow.hide()
                }
                
                logger.log("Input char: \(char)")
                _ = engine.handleInput(chars)
                
                // 更新 UI (組字視窗)
                let compositionDisplay = engine.compositionString
                let display = committedBuffer.joined() + compositionDisplay
                logger.log("Composition string: \(display)")
                client.setMarkedText(display, selectionRange: NSRange(location: display.count, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))

                // 聲調鍵（2/3/4/5聲）輸入完成後，將候選字加入緩衝區繼續輸入
                let toneKeys: Set<Character> = ["6", "3", "4", "7"]
                if toneKeys.contains(char) {
                    let hasChineseCandidate = engine.getCandidates().contains { containsCJK($0.text) }
                    if hasChineseCandidate {
                        logger.log("Tone key pressed, appending best to buffer for continuous input")
                        appendBestToBuffer(client)
                    }
                } else {
                    // 非聲調鍵：更新候選字視窗
                    updateCandidateWindow(client)
                }
                
                return true
            }
        }
        
        return false
    }
    
    override func commitComposition(_ sender: Any!) {
        guard let client = sender as? IMKTextInput else { return }
        commitBestCandidate(client)
    }
}

// MARK: - File Logger

class FileLogger {
    let logPath = "/tmp/smartime.log"
    
    func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] \(message)\n"
        
        if let data = entry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logPath) {
                if let fileHandle = FileHandle(forWritingAtPath: logPath) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    try? fileHandle.close()
                }
            } else {
                try? data.write(to: URL(fileURLWithPath: logPath))
            }
        }
    }
}
