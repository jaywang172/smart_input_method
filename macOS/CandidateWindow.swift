import Cocoa

/// 候選詞顯示視窗
/// 負責顯示和管理候選詞列表
class CandidateWindow: NSWindow {
    
    // MARK: - Properties
    
    private var candidates: [InputEngine.Candidate] = []
    private var currentInput = ""
    private var selectedIndex = 0
    
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let inputLabel = NSTextField()
    
    // MARK: - Initialization
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        setupWindow()
        setupUI()
    }
    
    convenience init() {
        let frame = NSRect(x: 0, y: 0, width: 400, height: 200)
        self.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    }
    
    // MARK: - Setup
    
    private func setupWindow() {
        self.level = .floating
        self.backgroundColor = NSColor.controlBackgroundColor
        self.hasShadow = true
        self.isOpaque = false
        self.ignoresMouseEvents = false
        self.animationBehavior = .utilityWindow
    }
    
    private func setupUI() {
        // 設置輸入標籤
        inputLabel.isEditable = false
        inputLabel.isBordered = false
        inputLabel.backgroundColor = .clear
        inputLabel.font = NSFont.systemFont(ofSize: 14)
        inputLabel.textColor = .labelColor
        
        // 設置表格視圖
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.selectionHighlightStyle = .regular
        tableView.target = self
        tableView.doubleAction = #selector(candidateDoubleClicked)
        
        // 設置滾動視圖
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        
        // 設置佈局
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 8
        stackView.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        
        stackView.addArrangedSubview(inputLabel)
        stackView.addArrangedSubview(scrollView)
        
        self.contentView = stackView
        
        // 設置約束
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: self.contentView!.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: self.contentView!.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: self.contentView!.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: self.contentView!.bottomAnchor)
        ])
    }
    
    // MARK: - Public Methods
    
    func updateCandidates(_ candidates: [InputEngine.Candidate], input: String, isBopomofoMode: Bool = false) {
        self.candidates = candidates
        self.currentInput = input
        self.selectedIndex = 0
        
        DispatchQueue.main.async {
            let mode = isBopomofoMode ? "注音" : "英文"
            self.inputLabel.stringValue = "\(mode)模式 - 輸入: \(input) (Cmd+Shift+M 切換模式)"
            self.tableView.reloadData()
            self.updateWindowSize()
            self.selectCandidate(at: 0)
        }
    }
    
    func show() {
        guard !candidates.isEmpty else { return }
        
        // 計算視窗位置（游標附近）
        let mouseLocation = NSEvent.mouseLocation
        let windowFrame = NSRect(
            x: mouseLocation.x - 200,
            y: mouseLocation.y - 100,
            width: 400,
            height: min(200, CGFloat(candidates.count) * 30 + 60)
        )
        
        self.setFrame(windowFrame, display: true)
        self.orderFront(nil)
    }
    
    func hide() {
        self.orderOut(nil)
    }
    
    // MARK: - Private Methods
    
    private func updateWindowSize() {
        let rowHeight: CGFloat = 30
        let headerHeight: CGFloat = 40
        let maxHeight: CGFloat = 200
        let height = min(maxHeight, CGFloat(candidates.count) * rowHeight + headerHeight)
        
        var frame = self.frame
        frame.size.height = height
        self.setFrame(frame, display: true)
    }
    
    private func selectCandidate(at index: Int) {
        guard index >= 0 && index < candidates.count else { return }
        
        selectedIndex = index
        tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        tableView.scrollRowToVisible(index)
    }
    
    @objc private func candidateDoubleClicked() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 && selectedRow < candidates.count else { return }
        
        let candidate = candidates[selectedRow]
        NotificationCenter.default.post(
            name: .candidateSelected,
            object: nil,
            userInfo: ["candidate": candidate]
        )
        
        hide()
    }
    
    // MARK: - Keyboard Handling
    
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 125: // Down arrow
            selectNextCandidate()
        case 126: // Up arrow
            selectPreviousCandidate()
        case 36: // Return
            confirmSelection()
        case 53: // Escape
            hide()
        default:
            super.keyDown(with: event)
        }
    }
    
    private func selectNextCandidate() {
        let nextIndex = min(selectedIndex + 1, candidates.count - 1)
        selectCandidate(at: nextIndex)
    }
    
    private func selectPreviousCandidate() {
        let prevIndex = max(selectedIndex - 1, 0)
        selectCandidate(at: prevIndex)
    }
    
    private func confirmSelection() {
        guard selectedIndex >= 0 && selectedIndex < candidates.count else { return }
        
        let candidate = candidates[selectedIndex]
        NotificationCenter.default.post(
            name: .candidateSelected,
            object: nil,
            userInfo: ["candidate": candidate]
        )
        
        hide()
    }
}

// MARK: - NSTableViewDataSource

extension CandidateWindow: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return candidates.count
    }
}

// MARK: - NSTableViewDelegate

extension CandidateWindow: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < candidates.count else { return nil }
        
        let candidate = candidates[row]
        let cell = NSTableCellView()
        
        let textField = NSTextField()
        textField.isEditable = false
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.font = NSFont.systemFont(ofSize: 14)
        textField.textColor = .labelColor
        textField.stringValue = "\(row + 1). \(candidate.text) (分數: \(String(format: "%.3f", candidate.score)))"
        
        cell.textField = textField
        cell.addSubview(textField)
        
        textField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        
        return cell
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 30
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let candidateSelected = Notification.Name("candidateSelected")
}
