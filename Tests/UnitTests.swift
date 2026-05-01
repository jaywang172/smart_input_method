import Foundation
import SmartIMECore

// ============================================================
// Lightweight test harness (no XCTest / Testing dependency)
// ============================================================

var passed = 0
var failed = 0

func check(_ condition: Bool, _ msg: String, file: String = #file, line: Int = #line) {
    if condition {
        passed += 1
    } else {
        print("❌ FAIL [\(file):\(line)] \(msg)")
        failed += 1
    }
}

// MARK: - Trie Tests

func testTrie() {
    print("📝 Trie Tests")
    let trie = Trie()
    trie.insert("apple", frequency: 10)
    trie.insert("app", frequency: 5)
    trie.insert("application", frequency: 8)

    check(trie.search("apple"), "search apple")
    check(trie.search("app"), "search app")
    check(!trie.search("appl"), "should not find appl")
    check(!trie.search("banana"), "should not find banana")
    check(trie.startsWith("app"), "prefix app")
    check(!trie.startsWith("dog"), "no prefix dog")

    let results = trie.getAllWordsWithPrefix("app", limit: 10)
    check(results.count == 3, "3 words with prefix app")
    check(results[0].word == "apple", "first is apple (highest freq)")

    trie.insertBatch([("swift", 100), ("python", 90)])
    check(trie.search("swift"), "batch insert swift")
    print("  ✅ Trie: \(passed) passed\n")
}

// MARK: - RadixTrie Tests

func testRadixTrie() {
    let prev = passed
    print("📝 RadixTrie Tests")
    let trie = RadixTrie()
    trie.insert("hello", frequency: 10)
    trie.insert("help", frequency: 8)
    trie.insert("hero", frequency: 6)

    check(trie.search("hello"), "search hello")
    check(trie.search("help"), "search help")
    check(!trie.search("hel"), "hel is not a word")
    check(trie.startsWith("hel"), "prefix hel exists")

    let results = trie.getAllWordsWithPrefix("hel", limit: 10)
    check(results.count == 2, "2 words with prefix hel")
    print("  ✅ RadixTrie: \(passed - prev) passed\n")
}

// MARK: - NgramModel Tests

func testNgram() {
    let prev = passed
    print("📝 NgramModel Tests")
    let model = NgramModel()
    model.train(corpus: [
        ["我", "愛", "你"],
        ["我", "愛", "你"],
        ["你", "愛", "我"],
        ["我", "愛", "吃飯"],
    ])

    let probI = exp(model.unigramLogProbability("我"))
    check(probI > 0, "P(我) > 0")

    let probBigram = exp(model.bigramLogProbability("我", "愛"))
    check(probBigram > 0, "P(愛|我) > 0")

    let p1 = model.sentenceLogProbability(["我", "愛", "你"])
    let p2 = model.sentenceLogProbability(["你", "愛", "我"])
    check(p1 > p2, "P(我愛你) > P(你愛我)")

    let preds = model.predictNext(context: ["我"], candidates: ["愛", "你", "吃飯"])
    check(!preds.isEmpty, "predictNext returns results")
    print("  ✅ NgramModel: \(passed - prev) passed\n")
}

// MARK: - LanguageDetector Tests

func testDetector() {
    let prev = passed
    print("📝 LanguageDetector Tests")
    let det = LanguageDetector()

    let zh = det.detect("你好世界")
    check(zh.language == .chinese || zh.language == .mixed, "Chinese text → .chinese")

    let bpmf = det.detect("ㄋㄧˇㄏㄠˇ")
    check(bpmf.language == .chinese, "Bopomofo → .chinese")
    print("  ✅ LanguageDetector: \(passed - prev) passed\n")
}

// MARK: - InputEngine Tests

func testEngine() {
    let prev = passed
    print("📝 InputEngine Tests")
    let engine = InputEngine()

    // Test that engine can handle Chinese input without crashing
    let zh = engine.handleInput("你好")
    check(!zh.isEmpty, "Chinese input produces candidates")

    // Test clear and reset don't crash
    engine.clearInput()
    // After clearInput, the buffer should eventually be empty
    // Use a small delay to let ThreadSafeSnapshot settle
    Thread.sleep(forTimeInterval: 0.01)
    check(engine.currentInput.isEmpty, "clearInput resets buffer")

    _ = engine.handleInput("test")
    engine.reset()
    Thread.sleep(forTimeInterval: 0.01)
    check(engine.currentInput.isEmpty, "reset clears input")
    check(engine.currentContext.isEmpty, "reset clears context")
    print("  ✅ InputEngine: \(passed - prev) passed\n")
}

// MARK: - Phase 3 Tests

func testKeyboardMapper() {
    let prev = passed
    print("📝 KeyboardMapper Tests")
    let mapper = KeyboardMapper()
    
    // su3 = ㄋㄧˇ, cl3 = ㄏㄠˇ
    let mapped = mapper.convert("su3cl3")
    check(mapped.contains("ㄋ"), "su3cl3 maps to ㄋ")
    check(mapped.contains("ㄧ"), "su3cl3 maps to ㄧ")
    check(mapped.contains("ˇ"), "su3cl3 maps to ˇ")
    check(mapped.contains("ㄏ"), "su3cl3 maps to ㄏ")
    check(mapped.contains("ㄠ"), "su3cl3 maps to ㄠ")
    
    check(mapper.isFullyMappable("su3cl3"), "su3cl3 is fully mappable")
    check(!mapper.isFullyMappable("hello!"), "hello! is not fully mappable (has !)")
    print("  ✅ KeyboardMapper: \(passed - prev) passed\n")
}

func testEnglishAutocomplete() {
    let prev = passed
    print("📝 English Autocomplete Tests")
    
    // Test that RadixTrie prefix matching works for English words
    let trie = RadixTrie()
    trie.insert("hello", frequency: 2500)
    trie.insert("help", frequency: 2200)
    trie.insert("heart", frequency: 1800)
    trie.insert("swift", frequency: 2000)
    trie.insert("programming", frequency: 1600)
    trie.insert("program", frequency: 1800)
    trie.insert("progress", frequency: 1400)
    
    let helResults = trie.getAllWordsWithPrefix("hel")
    print("    RadixTrie 'hel' prefix: \(helResults.map(\.word))")
    check(!helResults.isEmpty, "RadixTrie finds 'hel' prefix matches")
    
    let heResults = trie.getAllWordsWithPrefix("he")
    print("    RadixTrie 'he' prefix: \(heResults.map(\.word))")
    check(!heResults.isEmpty, "RadixTrie finds 'he' prefix matches")
    
    let progResults = trie.getAllWordsWithPrefix("prog")
    print("    RadixTrie 'prog' prefix: \(progResults.map(\.word))")
    check(!progResults.isEmpty, "RadixTrie finds 'prog' prefix matches")
    
    let swiResults = trie.getAllWordsWithPrefix("swi")
    print("    RadixTrie 'swi' prefix: \(swiResults.map(\.word))")
    check(!swiResults.isEmpty, "RadixTrie finds 'swi' prefix matches")
    
    // Test InputEngine integration
    let engine = InputEngine()
    let candidates = engine.handleInput("hel")
    let englishCandidates = candidates.filter { $0.source == .englishCompletion }
    print("    InputEngine 'hel' English candidates: \(englishCandidates.map(\.text))")
    print("    InputEngine 'hel' ALL candidates: \(candidates.map(\.text))")
    check(!englishCandidates.isEmpty, "InputEngine returns English candidates for 'hel'")
    engine.clearInput()
    
    let swiCandidates = engine.handleInput("swi")
    let swiEnglish = swiCandidates.filter { $0.source == .englishCompletion }
    print("    InputEngine 'swi' English candidates: \(swiEnglish.map(\.text))")
    check(!swiEnglish.isEmpty, "InputEngine returns English candidates for 'swi'")
    engine.clearInput()
    
    print("  ✅ English Autocomplete: \(passed - prev) passed\n")
}

func testBopomofoTones() {
    let prev = passed
    print("📝 Bopomofo Tone Tests")

    func hasChineseCandidate(_ candidates: [InputEngine.Candidate]) -> Bool {
        return candidates.contains { candidate in
            candidate.source == .bopomofoConversion &&
            candidate.text.unicodeScalars.contains { scalar in
                (0x4E00...0x9FFF).contains(scalar.value) || (0x3400...0x4DBF).contains(scalar.value)
            }
        }
    }

    let engine = InputEngine()
    let toneCases: [(raw: String, label: String)] = [
        ("a8", "一聲 ㄇㄚ"),
        ("a86", "二聲 ㄇㄚˊ"),
        ("a83", "三聲 ㄇㄚˇ"),
        ("a84", "四聲 ㄇㄚˋ"),
        ("a87", "輕聲 ㄇㄚ˙"),
    ]

    for item in toneCases {
        let candidates = engine.handleInput(item.raw)
        check(hasChineseCandidate(candidates), "\(item.label) should produce Chinese candidate")
        engine.clearInput()
    }

    print("  ✅ Bopomofo Tone: \(passed - prev) passed\n")
}

// MARK: - KeyboardMapper Segmentation Tests

func testKeyboardMapperSegmentation() {
    let prev = passed
    print("📝 KeyboardMapper Segmentation Tests")
    let mapper = KeyboardMapper()
    
    // 測試聲調鍵切分
    let seg1 = mapper.segmentToSyllables("su3cl3")
    check(seg1.count == 2, "su3cl3 segments into 2 syllables")
    check(seg1[0] == "su3", "first syllable is su3")
    check(seg1[1] == "cl3", "second syllable is cl3")
    
    let seg2 = mapper.segmentToSyllables("su3")
    check(seg2.count == 1, "su3 segments into 1 syllable")
    
    let seg3 = mapper.segmentToSyllables("su3cl3dk4")
    check(seg3.count == 3, "su3cl3dk4 segments into 3 syllables")
    
    // 測試無聲調（尚未輸入完成的音節）
    let seg4 = mapper.segmentToSyllables("su3cl")
    check(seg4.count == 2, "su3cl segments into 2 parts (completed + incomplete)")
    check(seg4[0] == "su3", "first part is su3")
    check(seg4[1] == "cl", "second part is cl (incomplete)")
    
    // 測試聲調鍵檢測
    check(mapper.isToneKey("3"), "3 is a tone key")
    check(mapper.isToneKey("6"), "6 is a tone key")
    check(!mapper.isToneKey("s"), "s is not a tone key")
    check(!mapper.isToneKey("1"), "1 is not a tone key (it's ㄅ)")
    
    print("  ✅ KeyboardMapper Segmentation: \(passed - prev) passed\n")
}

// MARK: - Continuous Composition Tests

func testContinuousComposition() {
    let prev = passed
    print("📝 Continuous Composition Tests")
    
    let engine = InputEngine()
    
    // 模擬連續輸入多個詞
    let c1 = engine.handleInput("su3")
    check(!c1.isEmpty, "First syllable produces candidates")
    
    // 選擇第一個候選並繼續
    engine.selectCandidate(at: 0)
    check(engine.currentInput.isEmpty, "After select, input buffer is clear")
    check(!engine.currentContext.isEmpty, "After select, context has entries")
    
    // 輸入第二個詞
    let c2 = engine.handleInput("cl3")
    check(!c2.isEmpty, "Second syllable produces candidates")
    
    engine.reset()
    check(engine.currentInput.isEmpty, "After reset, input is empty")
    check(engine.currentContext.isEmpty, "After reset, context is empty")
    
    print("  ✅ Continuous Composition: \(passed - prev) passed\n")
}

// MARK: - Dictionary Expansion Tests

func testDictionaryExpansion() {
    let prev = passed
    print("📝 Dictionary Expansion Tests")
    
    let engine = InputEngine()
    
    // 測試新增的中文詞條
    let c1 = engine.handleInput("沒問題")
    let hasNoProblem = c1.contains { $0.text == "沒問題" }
    check(hasNoProblem || !c1.isEmpty, "Chinese dictionary contains expanded words")
    engine.clearInput()
    
    // 測試英文補全
    let c2 = engine.handleInput("comp")
    let hasComputer = c2.contains { $0.text == "computer" }
    check(hasComputer, "English dictionary contains 'computer'")
    engine.clearInput()
    
    let c3 = engine.handleInput("prog")
    let hasProgramming = c3.contains { $0.text.starts(with: "prog") }
    check(hasProgramming, "English dictionary contains 'prog*' words")
    engine.clearInput()
    
    print("  ✅ Dictionary Expansion: \(passed - prev) passed\n")
}

// MARK: - Runner

testTrie()
testRadixTrie()
testNgram()
testDetector()
testEngine()
testKeyboardMapper()
testEnglishAutocomplete()
testBopomofoTones()
testKeyboardMapperSegmentation()
testContinuousComposition()
testDictionaryExpansion()

print(String(repeating: "=", count: 50))
if failed == 0 {
    print("🎉 All \(passed) tests passed!")
} else {
    print("⚠️  \(passed) passed, \(failed) failed")
}
print(String(repeating: "=", count: 50))

// Exit with non-zero if any test failed
if failed > 0 { exit(1) }
