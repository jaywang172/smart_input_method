import Cocoa

/// 候選字視窗控制器
/// 提供浮動候選字視窗，支援數字鍵/方向鍵選字
class CandidateWindowController {
    
    private var window: NSWindow?
    private var contentView: CandidateContentView?
    private var candidates: [String] = []
    private(set) var selectedIndex: Int = 0
    private var onSelect: ((Int) -> Void)?
    
    /// 候選字視窗是否可見
    var isVisible: Bool {
        return window?.isVisible ?? false
    }
    
    /// 候選字數量
    var candidateCount: Int {
        return candidates.count
    }
    
    init() {
        setupWindow()
    }
    
    // MARK: - Setup
    
    private func setupWindow() {
        let initialFrame = NSRect(x: 0, y: 0, width: 280, height: 40)
        
        let win = NSWindow(
            contentRect: initialFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.level = .floating
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.isReleasedWhenClosed = false
        // 確保候選窗不搶焦點
        win.hidesOnDeactivate = false
        win.collectionBehavior = [.canJoinAllSpaces, .stationary]
        
        let content = CandidateContentView(frame: initialFrame)
        win.contentView = content
        
        self.window = win
        self.contentView = content
    }
    
    // MARK: - Public API
    
    /// 顯示候選字
    /// - Parameters:
    ///   - candidates: 候選字列表
    ///   - cursorRect: 游標位置（螢幕座標）
    ///   - onSelect: 選字回調
    func show(candidates: [String], cursorRect: NSRect, onSelect: @escaping (Int) -> Void) {
        guard !candidates.isEmpty else {
            hide()
            return
        }
        
        self.candidates = Array(candidates.prefix(9)) // 最多顯示 9 個
        self.selectedIndex = 0
        self.onSelect = onSelect
        
        contentView?.update(candidates: self.candidates, selectedIndex: selectedIndex)
        
        // 計算視窗大小
        let itemHeight: CGFloat = 28
        let padding: CGFloat = 8
        let windowHeight = CGFloat(self.candidates.count) * itemHeight + padding * 2
        let windowWidth: CGFloat = 280
        
        // 定位：在游標下方
        let origin = NSPoint(
            x: cursorRect.origin.x,
            y: cursorRect.origin.y - windowHeight - 4
        )
        
        // 確保視窗不超出螢幕
        let adjustedOrigin = adjustForScreen(origin: origin, size: NSSize(width: windowWidth, height: windowHeight))
        
        window?.setFrame(
            NSRect(origin: adjustedOrigin, size: NSSize(width: windowWidth, height: windowHeight)),
            display: true
        )
        window?.orderFront(nil)
    }
    
    /// 隱藏候選字視窗
    func hide() {
        window?.orderOut(nil)
        candidates = []
        selectedIndex = 0
    }
    
    /// 移動選中項（方向鍵）
    /// - Parameter direction: 正數向下，負數向上
    func moveSelection(by direction: Int) {
        guard !candidates.isEmpty else { return }
        selectedIndex = (selectedIndex + direction + candidates.count) % candidates.count
        contentView?.update(candidates: candidates, selectedIndex: selectedIndex)
    }
    
    /// 確認當前選中項
    func confirmSelection() {
        guard selectedIndex < candidates.count else { return }
        onSelect?(selectedIndex)
    }
    
    /// 用數字鍵選字（1-9）
    /// - Parameter number: 數字 1-9
    /// - Returns: 是否成功選字
    @discardableResult
    func selectByNumber(_ number: Int) -> Bool {
        let index = number - 1
        guard index >= 0 && index < candidates.count else { return false }
        selectedIndex = index
        contentView?.update(candidates: candidates, selectedIndex: selectedIndex)
        onSelect?(index)
        return true
    }
    
    // MARK: - Private Helpers
    
    private func adjustForScreen(origin: NSPoint, size: NSSize) -> NSPoint {
        guard let screen = NSScreen.main else { return origin }
        let screenFrame = screen.visibleFrame
        
        var adjusted = origin
        
        // 如果超出螢幕右邊
        if adjusted.x + size.width > screenFrame.maxX {
            adjusted.x = screenFrame.maxX - size.width
        }
        
        // 如果超出螢幕左邊
        if adjusted.x < screenFrame.minX {
            adjusted.x = screenFrame.minX
        }
        
        // 如果超出螢幕下方，改為顯示在游標上方
        if adjusted.y < screenFrame.minY {
            adjusted.y = origin.y + size.height + 24
        }
        
        // 如果超出螢幕上方
        if adjusted.y + size.height > screenFrame.maxY {
            adjusted.y = screenFrame.maxY - size.height
        }
        
        return adjusted
    }
}

// MARK: - 候選字內容視圖

private class CandidateContentView: NSView {
    
    private var candidates: [String] = []
    private var selectedIndex: Int = 0
    
    private let itemHeight: CGFloat = 28
    private let padding: CGFloat = 8
    private let cornerRadius: CGFloat = 8
    
    // 顏色主題
    private let bgColor = NSColor(white: 0.15, alpha: 0.92)
    private let selectedBgColor = NSColor(calibratedRed: 0.2, green: 0.45, blue: 0.85, alpha: 0.9)
    private let textColor = NSColor.white
    private let indexColor = NSColor(white: 0.55, alpha: 1.0)
    private let separatorColor = NSColor(white: 0.3, alpha: 0.5)
    
    func update(candidates: [String], selectedIndex: Int) {
        self.candidates = candidates
        self.selectedIndex = selectedIndex
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard !candidates.isEmpty else { return }
        
        let path = NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius)
        
        // 背景
        bgColor.setFill()
        path.fill()
        
        // 邊框
        NSColor(white: 0.4, alpha: 0.6).setStroke()
        path.lineWidth = 0.5
        path.stroke()
        
        // 繪製候選字
        for (i, candidate) in candidates.enumerated() {
            let y = bounds.height - padding - CGFloat(i + 1) * itemHeight
            let itemRect = NSRect(x: 0, y: y, width: bounds.width, height: itemHeight)
            
            // 選中高亮
            if i == selectedIndex {
                let highlightRect = NSRect(
                    x: 4,
                    y: y + 2,
                    width: bounds.width - 8,
                    height: itemHeight - 4
                )
                let highlightPath = NSBezierPath(roundedRect: highlightRect, xRadius: 4, yRadius: 4)
                selectedBgColor.setFill()
                highlightPath.fill()
            }
            
            // 數字標籤
            let indexStr = "\(i + 1)"
            let indexAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
                .foregroundColor: i == selectedIndex ? NSColor(white: 0.85, alpha: 1.0) : indexColor
            ]
            let indexSize = indexStr.size(withAttributes: indexAttrs)
            indexStr.draw(
                at: NSPoint(x: 12, y: itemRect.midY - indexSize.height / 2),
                withAttributes: indexAttrs
            )
            
            // 候選字文本
            let textAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 16, weight: i == selectedIndex ? .semibold : .regular),
                .foregroundColor: textColor
            ]
            let textSize = candidate.size(withAttributes: textAttrs)
            candidate.draw(
                at: NSPoint(x: 32, y: itemRect.midY - textSize.height / 2),
                withAttributes: textAttrs
            )
            
            // 分隔線（非最後一項、非選中項的下方）
            if i < candidates.count - 1 && i != selectedIndex && i + 1 != selectedIndex {
                separatorColor.setStroke()
                let linePath = NSBezierPath()
                linePath.move(to: NSPoint(x: 12, y: y + 1))
                linePath.line(to: NSPoint(x: bounds.width - 12, y: y + 1))
                linePath.lineWidth = 0.5
                linePath.stroke()
            }
        }
    }
}
