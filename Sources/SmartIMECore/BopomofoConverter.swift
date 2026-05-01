import Foundation

/// 注音符號到中文的轉換器
/// 使用 Viterbi 演算法找出最佳轉換路徑
class BopomofoConverter {
    
    // 注音到中文的映射字典
    private var bopomofoDict: [String: [String]] = [:]
    private var normalizedBopomofoDict: [String: [String]] = [:]
    private let toneMarks: Set<Character> = ["ˊ", "ˇ", "ˋ", "˙"]
    
    // 注音符號分類
    private let initials: Set<Character> = [
        "ㄅ", "ㄆ", "ㄇ", "ㄈ", "ㄉ", "ㄊ", "ㄋ", "ㄌ",
        "ㄍ", "ㄎ", "ㄏ", "ㄐ", "ㄑ", "ㄒ",
        "ㄓ", "ㄔ", "ㄕ", "ㄖ", "ㄗ", "ㄘ", "ㄙ"
    ]
    private let medials: Set<Character> = ["ㄧ", "ㄨ", "ㄩ"]
    private let finals: Set<Character> = [
        "ㄚ", "ㄛ", "ㄜ", "ㄝ", "ㄞ", "ㄟ", "ㄠ", "ㄡ",
        "ㄢ", "ㄣ", "ㄤ", "ㄥ", "ㄦ"
    ]
    
    /// 將連續注音字串分段為個別音節
    /// 例如："ㄋㄧˇㄏㄠˇ" → ["ㄋㄧˇ", "ㄏㄠˇ"]
    func segmentSyllables(_ bopomofo: String) -> [String] {
        let chars = Array(bopomofo)
        var syllables: [String] = []
        var current = ""
        var hasInitial = false
        var hasMedial = false
        var hasFinal = false
        
        for ch in chars {
            if toneMarks.contains(ch) {
                // 聲調標記：結束當前音節
                current.append(ch)
                syllables.append(current)
                current = ""
                hasInitial = false
                hasMedial = false
                hasFinal = false
            } else if initials.contains(ch) {
                // 聲母：如果已有聲母/韻母/介音，先結束前一個音節
                if hasInitial || hasMedial || hasFinal {
                    if !current.isEmpty {
                        syllables.append(current)
                    }
                    current = ""
                    hasMedial = false
                    hasFinal = false
                }
                current.append(ch)
                hasInitial = true
            } else if medials.contains(ch) {
                // 介音：如果已有韻母，先結束前一個音節
                if hasFinal {
                    syllables.append(current)
                    current = ""
                    hasInitial = false
                    hasFinal = false
                }
                current.append(ch)
                hasMedial = true
            } else if finals.contains(ch) {
                // 韻母
                current.append(ch)
                hasFinal = true
            } else {
                // 其他字元（空格等）：結束當前音節
                if !current.isEmpty {
                    syllables.append(current)
                    current = ""
                    hasInitial = false
                    hasMedial = false
                    hasFinal = false
                }
            }
        }
        
        // 最後一個音節（沒有聲調標記的）
        if !current.isEmpty {
            syllables.append(current)
        }
        
        return syllables
    }
    
    // N-gram 語言模型用於上下文預測
    private let ngramModel: NgramModel
    
    // Trie 用於快速查找
    private let trie: WordLookup
    
    init(ngramModel: NgramModel, trie: WordLookup) {
        self.ngramModel = ngramModel
        self.trie = trie
        loadBopomofoMappings()
    }
    
    /// 載入注音符號映射表
    private func loadBopomofoMappings() {
        bopomofoDict = [
            // ===== 詞組 =====
            "ㄋㄧˇㄏㄠˇ": ["你好", "泥好"],
            "ㄨㄛˇㄇㄣˊ": ["我們"],
            "ㄊㄚㄇㄣˊ": ["他們", "她們", "它們"],
            "ㄕˊㄇㄜ˙": ["什麼"],
            "ㄇㄟˊㄧㄡˇ": ["沒有"],
            "ㄓ ㄉㄠˋ": ["知道"],
            "ㄎㄜˇㄧˇ": ["可以"],
            "ㄒㄧㄢˋㄗㄞˋ": ["現在"],
            "ㄧㄣ ㄨㄟˋ": ["因為"],
            "ㄙㄨㄛˇㄧˇ": ["所以"],
            "ㄖㄨˊㄍㄨㄛˇ": ["如果"],
            "ㄉㄢˋㄕˋ": ["但是"],
            "ㄈㄟ ㄔㄤˊ": ["非常"],
            "ㄧˇㄐㄧㄥ": ["已經"],
            "ㄎㄜˇㄋㄥˊ": ["可能"],
            "ㄒㄧ ㄨㄤˋ": ["希望"],
            "ㄒㄧㄝˋㄒㄧㄝˋ": ["謝謝"],
            "ㄗㄞˋㄐㄧㄢˋ": ["再見"],
            "ㄐㄧㄣ ㄊㄧㄢ": ["今天"],
            "ㄇㄧㄥˊㄊㄧㄢ": ["明天"],
            "ㄗㄨㄛˊㄊㄧㄢ": ["昨天"],
            "ㄊㄧㄢ ㄑㄧˋ": ["天氣"],
            "ㄒㄩㄝˊㄒㄧˊ": ["學習"],
            "ㄍㄨㄥ ㄗㄨㄛˋ": ["工作"],
            "ㄕㄥ ㄏㄨㄛˊ": ["生活"],
            "ㄆㄥˊㄧㄡˇ": ["朋友"],
            "ㄐㄧㄚ ㄖㄣˊ": ["家人"],
            "ㄌㄠˇㄕ": ["老師"],
            "ㄒㄩㄝˊㄕㄥ": ["學生"],
            "ㄒㄩㄝˊㄒㄧㄠˋ": ["學校"],
            "ㄍㄨㄥ ㄙ": ["公司"],
            "ㄉㄧㄢˋㄋㄠˇ": ["電腦"],
            "ㄕㄡˇㄐㄧ": ["手機"],
            "ㄔ ㄈㄢˋ": ["吃飯"],
            "ㄕㄨㄟˋㄐㄧㄠˋ": ["睡覺"],
            "ㄏㄜ ㄕㄨㄟˇ": ["喝水"],
            "ㄏㄨㄟˊㄐㄧㄚ": ["回家"],
            "ㄎㄞ ㄒㄧㄣ": ["開心"],
            "ㄎㄨㄞˋㄌㄜˋ": ["快樂"],
            "ㄆㄧㄠˋㄌㄧㄤˋ": ["漂亮"],
            "ㄎㄜˇㄞˋ": ["可愛"],
            "ㄓㄨㄥˋㄧㄠˋ": ["重要"],
            "ㄐㄧㄢˇㄉㄢ": ["簡單"],
            "ㄈㄤ ㄅㄧㄢˋ": ["方便"],

            // ===== 單字：ㄅ行 =====
            "ㄅㄚ": ["八", "巴", "吧", "爸"],
            "ㄅㄚˊ": ["拔", "跋"],
            "ㄅㄚˇ": ["把", "靶"],
            "ㄅㄚˋ": ["霸", "壩", "罷"],
            "ㄅㄞ": ["掰"],
            "ㄅㄞˊ": ["白", "百"],
            "ㄅㄞˇ": ["百", "擺", "柏"],
            "ㄅㄞˋ": ["拜", "敗", "唄"],
            "ㄅㄢ": ["班", "般", "搬", "斑", "扳", "頒"],
            "ㄅㄢˇ": ["板", "版"],
            "ㄅㄢˋ": ["半", "伴", "辦", "扮", "拌"],
            "ㄅㄤ": ["幫", "邦", "綁"],
            "ㄅㄤˋ": ["棒", "傍", "磅"],
            "ㄅㄠ": ["包", "胞"],
            "ㄅㄠˇ": ["保", "寶", "飽", "堡"],
            "ㄅㄠˋ": ["報", "抱", "暴", "爆", "豹"],
            "ㄅㄟ": ["杯", "悲", "卑"],
            "ㄅㄟˇ": ["北"],
            "ㄅㄟˋ": ["被", "備", "背", "倍", "輩"],
            "ㄅㄣ": ["奔", "笨"],
            "ㄅㄣˇ": ["本"],
            "ㄅㄧ": ["逼"],
            "ㄅㄧˇ": ["比", "筆", "彼", "鄙"],
            "ㄅㄧˋ": ["必", "畢", "閉", "幣", "壁", "避", "臂"],
            "ㄅㄧㄢ": ["邊", "編"],
            "ㄅㄧㄢˋ": ["便", "變", "遍", "辯", "辨"],
            "ㄅㄧㄠ": ["標", "表"],
            "ㄅㄧㄠˇ": ["表"],
            "ㄅㄧㄥ": ["冰", "兵"],
            "ㄅㄧㄥˋ": ["病", "並", "餅"],
            "ㄅㄛ": ["波", "播", "撥", "拨"],
            "ㄅㄛˊ": ["伯", "博", "薄"],
            "ㄅㄨ": ["不", "布", "步", "部"],
            "ㄅㄨˋ": ["不", "部", "步", "布", "怖"],

            // ===== ㄆ行 =====
            "ㄆㄚ": ["趴", "啪", "怕"],
            "ㄆㄚˋ": ["怕", "帕"],
            "ㄆㄞˊ": ["牌", "排", "徘"],
            "ㄆㄞˋ": ["派", "湃"],
            "ㄆㄢˊ": ["盤"],
            "ㄆㄢˋ": ["判", "盼", "叛"],
            "ㄆㄤ": ["旁", "胖"],
            "ㄆㄤˊ": ["旁", "龐"],
            "ㄆㄤˋ": ["胖"],
            "ㄆㄠˇ": ["跑"],
            "ㄆㄟˊ": ["陪", "培", "賠"],
            "ㄆㄥˊ": ["朋", "棚", "蓬", "膨"],
            "ㄆㄧ": ["批", "披", "劈"],
            "ㄆㄧˊ": ["皮", "疲", "脾"],
            "ㄆㄧˋ": ["屁", "闢", "僻"],
            "ㄆㄧㄢ": ["偏", "篇"],
            "ㄆㄧㄢˊ": ["便"],
            "ㄆㄧㄢˋ": ["片", "騙"],
            "ㄆㄧㄠ": ["飄", "漂"],
            "ㄆㄧㄠˋ": ["票", "漂"],
            "ㄆㄧㄣˊ": ["平", "評", "蘋", "貧", "頻", "瓶"],
            "ㄆㄧㄥˊ": ["平", "評", "蘋", "瓶"],
            "ㄆㄛˋ": ["破", "迫", "魄"],

            // ===== ㄇ行 =====
            "ㄇㄚ": ["媽", "嗎", "麻", "馬"],
            "ㄇㄚˇ": ["馬", "碼", "瑪"],
            "ㄇㄚˋ": ["罵", "嘛"],
            "ㄇㄚ˙": ["嗎", "嘛"],
            "ㄇㄞˇ": ["買"],
            "ㄇㄞˋ": ["賣", "邁", "麥", "脈"],
            "ㄇㄢˊ": ["滿", "蠻", "瞞"],
            "ㄇㄢˇ": ["滿"],
            "ㄇㄢˋ": ["慢", "漫", "蔓"],
            "ㄇㄤˊ": ["忙", "盲", "芒", "茫"],
            "ㄇㄠ": ["貓"],
            "ㄇㄠˊ": ["毛", "矛", "茅"],
            "ㄇㄠˋ": ["帽", "冒", "貌", "貿", "茂"],
            "ㄇㄟˊ": ["沒", "美", "梅", "媒", "煤", "眉"],
            "ㄇㄟˇ": ["美", "每"],
            "ㄇㄟˋ": ["妹", "昧", "魅"],
            "ㄇㄣˊ": ["們", "門", "悶"],
            "ㄇㄥˊ": ["夢", "萌", "盟", "猛", "蒙"],
            "ㄇㄧˇ": ["米", "秘", "迷"],
            "ㄇㄧˋ": ["密", "秘", "蜜", "覓"],
            "ㄇㄧㄢˊ": ["綿", "棉"],
            "ㄇㄧㄢˇ": ["免", "面", "勉"],
            "ㄇㄧㄢˋ": ["面", "麵"],
            "ㄇㄧㄥˊ": ["明", "名", "命", "鳴"],
            "ㄇㄧㄥˋ": ["命"],
            "ㄇㄛˊ": ["模", "摸", "磨", "膜"],
            "ㄇㄨˇ": ["母", "木", "目"],
            "ㄇㄨˋ": ["目", "木", "幕", "墓", "暮"],

            // ===== ㄈ行 =====
            "ㄈㄚ": ["發", "法"],
            "ㄈㄚˇ": ["法"],
            "ㄈㄚˋ": ["罰", "髮"],
            "ㄈㄢ": ["翻", "番", "帆"],
            "ㄈㄢˊ": ["凡", "煩", "繁"],
            "ㄈㄢˇ": ["反", "返"],
            "ㄈㄢˋ": ["飯", "犯", "範", "泛"],
            "ㄈㄤ": ["方", "芳"],
            "ㄈㄤˊ": ["房", "防", "妨", "坊"],
            "ㄈㄤˋ": ["放", "訪"],
            "ㄈㄟ": ["飛", "非"],
            "ㄈㄟˊ": ["肥"],
            "ㄈㄥ": ["風", "豐", "瘋", "封", "蜂", "楓", "鋒"],
            "ㄈㄥˊ": ["逢", "縫", "馮"],
            "ㄈㄨˊ": ["服", "福", "符", "扶", "浮", "幅", "伏"],
            "ㄈㄨˋ": ["父", "付", "附", "負", "婦", "復", "副", "富", "複"],

            // ===== ㄉ行 =====
            "ㄉㄚ": ["打", "搭", "大", "達"],
            "ㄉㄚˇ": ["打"],
            "ㄉㄚˋ": ["大", "達"],
            "ㄉㄞ": ["待", "呆", "帶"],
            "ㄉㄞˋ": ["帶", "代", "待", "袋", "戴"],
            "ㄉㄢ": ["單", "丹", "擔"],
            "ㄉㄢˋ": ["但", "蛋", "淡", "彈", "旦", "誕"],
            "ㄉㄤ": ["當"],
            "ㄉㄤˋ": ["當", "擋", "黨"],
            "ㄉㄠ": ["刀", "到"],
            "ㄉㄠˇ": ["倒", "島", "導", "搗"],
            "ㄉㄠˋ": ["到", "道", "倒", "稻", "盜"],
            "ㄉㄜˊ": ["得", "德"],
            "ㄉㄜ˙": ["的", "得", "地"],
            "ㄉㄥ": ["燈", "登", "等"],
            "ㄉㄧ": ["低", "滴", "敵"],
            "ㄉㄧˇ": ["底", "抵"],
            "ㄉㄧˋ": ["地", "第", "弟", "帝", "遞", "的"],
            "ㄉㄧㄢˇ": ["點", "典", "電"],
            "ㄉㄧㄢˋ": ["電", "店", "殿", "墊"],
            "ㄉㄧㄥ": ["丁", "叮", "頂", "定"],
            "ㄉㄧㄥˋ": ["定", "訂"],
            "ㄉㄨ": ["都", "督"],
            "ㄉㄨˊ": ["讀", "獨", "毒", "度"],
            "ㄉㄨˋ": ["度", "渡"],
            "ㄉㄨㄟˋ": ["對", "隊"],
            "ㄉㄨㄛ": ["多"],
            "ㄉㄨㄛˇ": ["朵", "躲"],
            "ㄉㄨㄥ": ["東", "冬", "懂", "動"],
            "ㄉㄨㄥˇ": ["懂", "董"],
            "ㄉㄨㄥˋ": ["動", "洞", "凍"],

            // ===== ㄊ行 =====
            "ㄊㄚ": ["他", "她", "它", "塔", "踏"],
            "ㄊㄞˊ": ["台", "抬", "太", "態"],
            "ㄊㄞˋ": ["太", "態", "泰"],
            "ㄊㄢ": ["貪", "攤"],
            "ㄊㄢˊ": ["談", "彈", "壇", "檀", "潭"],
            "ㄊㄤ": ["湯", "趟", "糖"],
            "ㄊㄤˊ": ["堂", "唐", "糖", "塘"],
            "ㄊㄤˇ": ["躺"],
            "ㄊㄠˊ": ["逃", "桃", "陶", "淘"],
            "ㄊㄧ": ["提", "踢"],
            "ㄊㄧˊ": ["提", "題"],
            "ㄊㄧˇ": ["體"],
            "ㄊㄧㄢ": ["天", "添", "田", "甜"],
            "ㄊㄧㄢˊ": ["甜", "田", "填"],
            "ㄊㄧㄠˊ": ["條"],
            "ㄊㄧㄥ": ["聽", "庭", "停", "亭", "挺"],
            "ㄊㄧㄥˊ": ["停", "庭", "亭", "廷"],
            "ㄊㄧㄥˇ": ["挺"],
            "ㄊㄨˊ": ["圖", "途", "徒", "屠"],
            "ㄊㄨˇ": ["土", "吐"],
            "ㄊㄨㄟ": ["推", "退"],
            "ㄊㄨㄟˋ": ["退"],
            "ㄊㄨㄥˊ": ["同", "童", "銅", "桐"],
            "ㄊㄨㄥˇ": ["統", "桶", "筒"],
            "ㄊㄨㄥˋ": ["痛", "通"],

            // ===== ㄋ行 =====
            "ㄋㄚ": ["那", "拿", "哪", "納"],
            "ㄋㄚˇ": ["哪", "那"],
            "ㄋㄚˋ": ["那", "納"],
            "ㄋㄞˇ": ["奶", "乃", "耐"],
            "ㄋㄞˋ": ["耐", "奈"],
            "ㄋㄢˊ": ["南", "男", "難"],
            "ㄋㄢˇ": ["難"],
            "ㄋㄤˋ": ["讓"],
            "ㄋㄠˇ": ["腦", "惱", "鬧"],
            "ㄋㄟˇ": ["內"],
            "ㄋㄟˋ": ["內"],
            "ㄋㄥˊ": ["能"],
            "ㄋㄧˇ": ["你", "泥", "擬", "妳"],
            "ㄋㄧˋ": ["逆", "膩"],
            "ㄋㄧㄢˊ": ["年", "粘"],
            "ㄋㄧㄢˋ": ["念", "唸"],
            "ㄋㄧㄤˊ": ["娘"],
            "ㄋㄧㄠˇ": ["鳥"],
            "ㄋㄧㄡˊ": ["牛"],
            "ㄋㄩˇ": ["女"],

            // ===== ㄌ行 =====
            "ㄌㄚ": ["拉", "啦"],
            "ㄌㄞˊ": ["來"],
            "ㄌㄠˇ": ["老"],
            "ㄌㄜˋ": ["樂", "勒", "了"],
            "ㄌㄜ˙": ["了"],
            "ㄌㄟˇ": ["累"],
            "ㄌㄟˋ": ["累", "類", "淚", "雷"],
            "ㄌㄧ": ["裡", "離", "理", "禮"],
            "ㄌㄧˇ": ["理", "裡", "里", "禮", "李"],
            "ㄌㄧˋ": ["力", "立", "利", "歷", "例", "麗", "厲"],
            "ㄌㄧㄢˊ": ["連", "聯", "蓮", "練"],
            "ㄌㄧㄢˇ": ["臉"],
            "ㄌㄧㄤˊ": ["良", "涼", "糧", "梁", "量"],
            "ㄌㄧㄤˋ": ["量", "亮", "諒"],
            "ㄌㄧㄥˊ": ["零", "靈", "鈴", "領"],
            "ㄌㄨˋ": ["路", "錄", "陸", "鹿", "綠"],
            "ㄌㄩˇ": ["旅", "綠", "呂", "侶"],
            "ㄌㄨㄛˋ": ["落", "洛", "絡"],

            // ===== ㄍ行 =====
            "ㄍㄜ": ["哥", "歌", "割", "各"],
            "ㄍㄜˇ": ["各", "個"],
            "ㄍㄜˋ": ["個", "各"],
            "ㄍㄞ": ["該", "改"],
            "ㄍㄞˇ": ["改"],
            "ㄍㄠ": ["高", "告"],
            "ㄍㄠˋ": ["告"],
            "ㄍㄡˇ": ["狗", "夠", "苟"],
            "ㄍㄡˋ": ["夠", "構", "購"],
            "ㄍㄨㄚ": ["瓜", "刮"],
            "ㄍㄨㄛˊ": ["國", "過"],
            "ㄍㄨㄛˋ": ["過"],
            "ㄍㄨㄢ": ["關", "官", "觀", "管"],
            "ㄍㄨㄢˇ": ["管", "館"],
            "ㄍㄨㄤ": ["光", "廣"],
            "ㄍㄨㄥ": ["工", "公", "功", "攻", "宮", "共"],
            "ㄍㄨㄥˋ": ["共", "供", "貢"],
            "ㄍㄟˇ": ["給"],

            // ===== ㄎ行 =====
            "ㄎㄜˇ": ["可", "渴"],
            "ㄎㄜˋ": ["客", "刻", "課", "克"],
            "ㄎㄞ": ["開", "凱"],
            "ㄎㄢ": ["看", "砍", "刊"],
            "ㄎㄢˋ": ["看"],
            "ㄎㄡˇ": ["口"],
            "ㄎㄨ": ["哭", "苦", "酷"],
            "ㄎㄨˇ": ["苦"],
            "ㄎㄨˋ": ["酷", "庫", "褲"],
            "ㄎㄨㄞˋ": ["快", "塊", "筷"],
            "ㄎㄨㄥ": ["空", "孔", "恐"],
            "ㄎㄨㄥˇ": ["孔", "恐"],

            // ===== ㄏ行 =====
            "ㄏㄚ": ["哈"],
            "ㄏㄞˇ": ["海", "還"],
            "ㄏㄞˊ": ["還", "孩"],
            "ㄏㄠˇ": ["好", "號", "豪"],
            "ㄏㄜˊ": ["和", "河", "合", "何", "核"],
            "ㄏㄟ": ["黑", "嘿"],
            "ㄏㄣˇ": ["很", "狠"],
            "ㄏㄨ": ["呼", "乎", "忽"],
            "ㄏㄨˊ": ["湖", "壺", "胡"],
            "ㄏㄨㄚ": ["花", "化", "華", "話"],
            "ㄏㄨㄚˊ": ["華", "滑", "划"],
            "ㄏㄨㄚˋ": ["話", "化", "畫", "劃"],
            "ㄏㄨㄛˇ": ["火", "夥", "伙"],
            "ㄏㄨㄟˊ": ["回", "灰", "會"],
            "ㄏㄨㄟˋ": ["會", "匯", "繪"],
            "ㄏㄡˋ": ["後", "候", "厚"],
            "ㄏㄡˊ": ["猴", "侯"],

            // ===== ㄐ行 =====
            "ㄐㄧ": ["基", "機", "雞", "積", "擊", "及", "即", "急", "級"],
            "ㄐㄧˇ": ["幾", "己", "擠"],
            "ㄐㄧˋ": ["記", "技", "計", "季", "繼", "際", "寄", "紀"],
            "ㄐㄧㄚ": ["家", "加", "佳", "架", "假"],
            "ㄐㄧㄚˇ": ["假", "甲"],
            "ㄐㄧㄚˋ": ["假", "架", "價", "駕", "嫁"],
            "ㄐㄧㄢ": ["間", "見", "件", "建", "尖", "堅", "漸", "肩", "兼"],
            "ㄐㄧㄢˇ": ["減", "簡", "剪", "檢", "撿"],
            "ㄐㄧㄢˋ": ["見", "件", "建", "劍", "健", "鍵", "鑒", "漸"],
            "ㄐㄧㄡ": ["就", "九", "久", "酒", "舊", "救"],
            "ㄐㄧㄡˇ": ["九", "久", "酒"],
            "ㄐㄧㄡˋ": ["就", "舊", "救"],
            "ㄐㄧㄣ": ["今", "金", "進", "近", "斤", "筋", "巾"],
            "ㄐㄧㄣˋ": ["進", "近", "盡", "勁", "禁", "晉"],
            "ㄐㄧㄥ": ["經", "驚", "精", "京", "景"],
            "ㄐㄩ": ["居", "舉", "句", "劇", "距", "具"],
            "ㄐㄩˇ": ["舉"],
            "ㄐㄩˋ": ["句", "具", "劇", "巨", "距", "據", "聚"],
            "ㄐㄩㄝˊ": ["決", "覺", "絕", "角"],

            // ===== ㄑ行 =====
            "ㄑㄧ": ["七", "期", "其", "起"],
            "ㄑㄧˊ": ["其", "期", "奇", "棋", "旗", "騎", "齊"],
            "ㄑㄧˇ": ["起", "企", "啟"],
            "ㄑㄧˋ": ["氣", "器", "汽", "棄", "契"],
            "ㄑㄧㄢ": ["千", "前", "錢", "牽", "淺", "簽"],
            "ㄑㄧㄢˊ": ["前", "錢", "潛"],
            "ㄑㄧㄢˇ": ["淺"],
            "ㄑㄧㄥ": ["青", "清", "輕", "情", "晴", "請"],
            "ㄑㄧㄥˊ": ["情", "晴"],
            "ㄑㄧㄥˇ": ["請"],
            "ㄑㄩ": ["去", "區", "趣", "取"],
            "ㄑㄩˊ": ["區", "渠"],
            "ㄑㄩˇ": ["取", "娶"],
            "ㄑㄩˋ": ["去", "趣"],
            "ㄑㄩㄢˊ": ["全", "權", "泉", "拳"],

            // ===== ㄒ行 =====
            "ㄒㄧ": ["西", "希", "息", "吸", "惜", "溪", "洗", "喜", "習", "席", "系"],
            "ㄒㄧˇ": ["喜", "洗", "戲"],
            "ㄒㄧˋ": ["系", "細", "戲"],
            "ㄒㄧㄚ": ["下", "嚇", "蝦", "夏"],
            "ㄒㄧㄚˋ": ["下", "夏", "嚇"],
            "ㄒㄧㄢ": ["先", "鮮", "仙", "線", "現"],
            "ㄒㄧㄢˋ": ["現", "線", "限", "險", "獻", "縣", "顯"],
            "ㄒㄧㄤ": ["想", "相", "香", "箱", "鄉", "享", "響"],
            "ㄒㄧㄤˇ": ["想", "響", "享"],
            "ㄒㄧㄤˋ": ["像", "象", "向", "項"],
            "ㄒㄧㄠ": ["小", "笑", "消", "校", "效"],
            "ㄒㄧㄠˇ": ["小", "曉"],
            "ㄒㄧㄠˋ": ["笑", "校", "效"],
            "ㄒㄧㄝ": ["些", "寫", "謝", "歇"],
            "ㄒㄧㄝˇ": ["寫", "血"],
            "ㄒㄧㄝˋ": ["謝", "卸"],
            "ㄒㄧㄣ": ["心", "新", "信", "辛", "星", "欣"],
            "ㄒㄧㄣˋ": ["信"],
            "ㄒㄧㄥ": ["星", "興", "行", "性", "姓", "型"],
            "ㄒㄧㄥˊ": ["行", "形", "型", "刑"],
            "ㄒㄧㄥˋ": ["性", "姓", "興"],
            "ㄒㄩ": ["需", "須", "虛", "許", "序"],
            "ㄒㄩˇ": ["許"],
            "ㄒㄩˋ": ["續", "序", "緒", "敘", "畜"],
            "ㄒㄩㄝˊ": ["學"],
            "ㄒㄩㄝˇ": ["雪", "血"],

            // ===== ㄓ行 =====
            "ㄓ": ["之", "知", "只", "支", "織", "汁", "直"],
            "ㄓˊ": ["直", "值", "職", "植"],
            "ㄓˇ": ["只", "指", "紙", "止", "址"],
            "ㄓˋ": ["至", "治", "制", "志", "置", "智", "質"],
            "ㄓㄚˇ": ["找"],
            "ㄓㄠ": ["找", "招", "朝"],
            "ㄓㄠˇ": ["找"],
            "ㄓㄢ": ["站", "占", "戰", "展"],
            "ㄓㄢˇ": ["展"],
            "ㄓㄢˋ": ["站", "戰", "占"],
            "ㄓㄤ": ["張", "章", "長", "丈"],
            "ㄓㄤˇ": ["長", "掌", "漲"],
            "ㄓㄤˋ": ["丈", "帳", "障", "脹"],
            "ㄓㄜ": ["著"],
            "ㄓㄜˇ": ["這"],
            "ㄓㄜˋ": ["這", "著"],
            "ㄓㄣ": ["真", "珍", "針", "陣", "鎮"],
            "ㄓㄣˋ": ["陣", "鎮", "震", "振"],
            "ㄓㄥ": ["正", "整", "爭", "徵", "睜", "政"],
            "ㄓㄥˇ": ["整"],
            "ㄓㄥˋ": ["正", "政", "證", "鄭", "掙"],
            "ㄓㄨ": ["豬", "竹", "主", "住", "注", "祝", "煮"],
            "ㄓㄨˇ": ["主", "煮", "屬"],
            "ㄓㄨˋ": ["住", "注", "祝", "著", "助", "柱", "駐"],
            "ㄓㄨㄥ": ["中", "終", "鐘", "忠", "種", "眾"],
            "ㄓㄨㄥˇ": ["種"],
            "ㄓㄨㄥˋ": ["重", "種", "眾", "仲"],
            "ㄓㄨㄢ": ["專", "轉"],
            "ㄓㄨㄢˇ": ["轉"],
            "ㄓㄨㄤ": ["裝", "莊", "壯", "撞", "狀"],
            "ㄓㄨㄤˋ": ["壯", "撞", "狀"],
            "ㄓㄨㄟ": ["追"],
            "ㄓㄨㄣˇ": ["準"],

            // ===== ㄔ行 =====
            "ㄔ": ["吃", "尺", "遲", "持"],
            "ㄔˊ": ["遲", "持", "池"],
            "ㄔㄚ": ["查", "茶", "差", "插", "察"],
            "ㄔㄚˊ": ["查", "茶", "察"],
            "ㄔㄤˊ": ["長", "常", "場", "腸", "嚐"],
            "ㄔㄤˇ": ["場", "廠", "敞"],
            "ㄔㄤˋ": ["唱", "暢"],
            "ㄔㄜ": ["車"],
            "ㄔㄥˊ": ["成", "城", "程", "誠", "承", "呈"],
            "ㄔㄨ": ["出", "初", "除", "處"],
            "ㄔㄨˊ": ["除", "廚"],
            "ㄔㄨˇ": ["處", "楚"],
            "ㄔㄨㄢ": ["穿", "傳", "船", "川", "串"],
            "ㄔㄨㄢˊ": ["傳", "船"],
            "ㄔㄨㄣ": ["春"],
            "ㄔㄨㄥ": ["充", "蟲", "衝", "沖"],

            // ===== ㄕ行 =====
            "ㄕ": ["詩", "師", "十", "石", "時", "食", "識", "史", "使"],
            "ㄕˊ": ["十", "石", "時", "食", "識", "實"],
            "ㄕˇ": ["史", "使", "始"],
            "ㄕˋ": ["是", "事", "室", "世", "士", "市", "勢", "式", "試", "視", "示"],
            "ㄕㄡ": ["收", "手"],
            "ㄕㄡˇ": ["手", "首", "守"],
            "ㄕㄡˋ": ["受", "授", "瘦", "獸", "售", "壽"],
            "ㄕㄢ": ["山", "衫", "善", "扇"],
            "ㄕㄤ": ["上", "商", "傷"],
            "ㄕㄤˋ": ["上"],
            "ㄕㄜˊ": ["蛇", "舌", "什"],
            "ㄕㄣ": ["深", "身", "伸", "神", "生", "聲", "申"],
            "ㄕㄣˊ": ["神", "什"],
            "ㄕㄥ": ["生", "聲", "升", "勝", "省"],
            "ㄕㄨ": ["書", "輸", "舒", "叔", "熟", "數", "屬", "樹", "束"],
            "ㄕㄨˊ": ["熟", "書", "叔"],
            "ㄕㄨˇ": ["數", "鼠", "暑"],
            "ㄕㄨˋ": ["數", "樹", "術", "束", "述", "豎"],
            "ㄕㄨㄛ": ["說"],
            "ㄕㄨㄟˇ": ["水", "睡"],
            "ㄕㄨㄟˋ": ["睡"],

            // ===== ㄖ行 =====
            "ㄖˋ": ["日"],
            "ㄖㄣˊ": ["人", "仁", "認"],
            "ㄖㄣˋ": ["認", "任"],
            "ㄖㄤˋ": ["讓"],
            "ㄖㄜˋ": ["熱"],
            "ㄖㄨˊ": ["如", "入"],

            // ===== ㄗ行 =====
            "ㄗˇ": ["子", "字", "自", "紫"],
            "ㄗˋ": ["字", "自"],
            "ㄗㄞˋ": ["在", "再", "載"],
            "ㄗㄠˇ": ["早", "澡"],
            "ㄗㄣˇ": ["怎"],
            "ㄗㄡˇ": ["走"],
            "ㄗㄨˇ": ["祖", "組", "族", "阻"],
            "ㄗㄨˋ": ["族", "足"],
            "ㄗㄨㄟˇ": ["最", "嘴"],
            "ㄗㄨㄟˋ": ["最", "醉", "罪"],
            "ㄗㄨㄛˋ": ["做", "坐", "座", "作"],
            "ㄗㄨㄛˊ": ["昨"],

            // ===== ㄘ行 =====
            "ㄘˊ": ["詞", "辭", "瓷", "慈", "磁"],
            "ㄘˋ": ["次", "刺"],
            "ㄘㄞˊ": ["才", "材", "財", "裁"],
            "ㄘㄞˋ": ["菜", "蔡"],
            "ㄘㄤˊ": ["藏"],
            "ㄘㄤˋ": ["藏"],
            "ㄘㄥˊ": ["層", "曾"],
            "ㄘㄨㄥ": ["聰"],
            "ㄘㄨㄥˊ": ["從"],

            // ===== ㄙ行 =====
            "ㄙ": ["思", "私", "斯", "撕", "四", "死", "絲", "司"],
            "ㄙˇ": ["死"],
            "ㄙˋ": ["四", "似", "寺"],
            "ㄙㄢ": ["三", "散"],
            "ㄙㄤ": ["喪"],
            "ㄙㄨ": ["蘇", "素", "速", "訴"],
            "ㄙㄨˋ": ["素", "速", "訴", "宿", "塑"],
            "ㄙㄨㄟˋ": ["歲", "碎", "隨", "雖"],
            "ㄙㄨㄟˊ": ["隨", "雖"],
            "ㄙㄨㄣ": ["孫", "損"],
            "ㄙㄨㄥˋ": ["送", "頌", "宋"],

            // ===== ㄧ行（零聲母）=====
            "ㄧ": ["一", "衣", "依"],
            "ㄧˊ": ["移", "疑", "宜", "姨"],
            "ㄧˇ": ["以", "已", "椅", "倚"],
            "ㄧˋ": ["意", "義", "一", "益", "易", "議", "藝", "億", "憶"],
            "ㄧㄝˋ": ["業", "葉", "夜", "頁"],
            "ㄧㄡˇ": ["有", "友", "右", "又", "油", "游", "遊", "由", "猶", "優"],
            "ㄧㄡˊ": ["由", "油", "游", "遊", "猶", "尤", "郵", "優"],
            "ㄧㄡˋ": ["又", "右", "幼", "佑"],
            "ㄧㄣ": ["因", "音", "陰"],
            "ㄧㄥ": ["英", "應", "影", "營", "迎"],
            "ㄧㄥˊ": ["營", "迎", "贏", "盈"],
            "ㄧㄥˇ": ["影"],
            "ㄧㄥˋ": ["應", "映", "硬"],

            // ===== ㄨ行 =====
            "ㄨˇ": ["五", "午", "武", "舞"],
            "ㄨˋ": ["物", "務", "悟", "霧", "誤"],
            "ㄨㄛˇ": ["我", "握", "臥"],
            "ㄨㄞˋ": ["外"],
            "ㄨㄢˊ": ["完", "玩", "丸", "灣", "碗", "晚", "萬"],
            "ㄨㄢˇ": ["晚", "碗", "挽"],
            "ㄨㄢˋ": ["萬", "灣"],
            "ㄨㄤˊ": ["王", "亡", "忘", "望", "往"],
            "ㄨㄤˋ": ["望", "忘", "旺"],
            "ㄨㄟˊ": ["為", "圍", "維", "唯", "違", "微"],
            "ㄨㄟˋ": ["為", "位", "味", "胃", "衛", "未", "畏", "謂"],
            "ㄨㄣˊ": ["文", "聞", "紋", "問"],
            "ㄨㄣˋ": ["問", "穩"],
            "ㄨㄥ": ["翁"],

            // ===== ㄩ行 =====
            "ㄩˊ": ["魚", "餘", "於", "愚", "漁", "娛", "與", "語", "雨", "宇", "羽"],
            "ㄩˇ": ["雨", "語", "與", "宇", "羽", "予"],
            "ㄩˋ": ["遇", "育", "玉", "域", "慾", "御", "預", "譽", "獄"],
            "ㄩㄢ": ["元", "原", "園", "圓", "遠", "源", "員", "院", "願", "冤"],
            "ㄩㄢˊ": ["元", "原", "園", "圓", "源", "員"],
            "ㄩㄢˇ": ["遠"],
            "ㄩㄢˋ": ["院", "願", "怨"],
            "ㄩㄝˋ": ["月", "越", "閱", "約", "樂", "悅"],
            "ㄩㄥˇ": ["勇", "永", "涌", "擁"],

            // ===== ㄚ行（零聲母）=====
            "ㄚ": ["阿", "啊"],
            "ㄞˋ": ["愛", "礙"],
            "ㄢ": ["安", "暗", "按"],
            "ㄢˋ": ["暗", "按", "案", "岸"],
            "ㄤ": ["骯"],
            "ㄠ": ["凹"],

            // ===== ㄜ/ㄦ行 =====
            "ㄜˋ": ["惡", "餓", "額"],
            "ㄦˊ": ["兒", "而", "耳"],
            "ㄦˇ": ["耳", "爾", "二"],
            "ㄦˋ": ["二"],
            
            // ===== 補充：更多常用詞組 =====
            "ㄉㄧㄢˋㄏㄨㄚˋ": ["電話"],
            "ㄕˊㄐㄧㄢ": ["時間"],
            "ㄨㄣˋㄊㄧˊ": ["問題"],
            "ㄉㄨㄥ ㄒㄧ": ["東西"],
            "ㄏㄞˊㄗˇ": ["孩子"],
            "ㄧˇㄑㄧㄢˊ": ["以前"],
            "ㄧˇㄏㄡˋ": ["以後"],
            "ㄎㄞ ㄕˇ": ["開始"],
            "ㄐㄧㄝˊㄕˋ": ["結束"],
            "ㄨㄢˊㄔㄥˊ": ["完成"],
            "ㄓㄨㄣˇㄅㄟˋ": ["準備"],
            "ㄐㄩㄝˊㄉㄧㄥˋ": ["決定"],
            "ㄒㄩㄢˇㄗㄜˊ": ["選擇"],
            "ㄍㄞˇㄅㄧㄢˋ": ["改變"],
            "ㄐㄧˋㄒㄩˋ": ["繼續"],
            "ㄊㄧㄥˊㄓˇ": ["停止"],
            "ㄌㄧˊㄎㄞ": ["離開"],
            "ㄏㄨㄟˊㄌㄞˊ": ["回來"],
            "ㄔㄨ ㄑㄩˋ": ["出去"],
            "ㄐㄧㄣˋㄌㄞˊ": ["進來"],
            "ㄇㄟˇㄊㄧㄢ": ["每天"],
            "ㄒㄧㄥ ㄑㄧ": ["星期"],
            "ㄓㄡ ㄇㄛˋ": ["週末"],
            "ㄧ ㄑㄧˇ": ["一起"],
            "ㄖㄢˊㄏㄡˋ": ["然後"],
            "ㄌㄧˋㄖㄨˊ": ["例如"],
            "ㄓㄨˋㄧˋ": ["注意"],
            "ㄒㄧㄠˇㄒㄧㄣ": ["小心"],
            "ㄔㄥˊㄍㄨㄥ": ["成功"],
            "ㄕ ㄅㄞˋ": ["失敗"],
            "ㄐㄧ ㄏㄨㄟˋ": ["機會"],
            "ㄋㄨˇㄌㄧˋ": ["努力"],
            "ㄖㄣˋㄓㄣ": ["認真"],
            "ㄈㄤ ㄈㄚˇ": ["方法"],
            "ㄅㄧˇㄐㄧㄠˋ": ["比較"],
            "ㄊㄜˋㄅㄧㄝˊ": ["特別"],
            "ㄌㄧˋㄏㄞˋ": ["厲害"],
            
            // 更多日常口語

            "ㄅㄨˋㄎㄜˋㄑㄧˋ": ["不客氣"],
            "ㄇㄟˊㄍㄨㄢ ㄒㄧˋ": ["沒關係"],
            "ㄉㄨㄟˋㄅㄨˋㄑㄧˇ": ["對不起"],
            "ㄅㄨˋㄏㄠˇㄧˋㄙ": ["不好意思"],
            "ㄑㄧㄥˇㄨㄣˋ": ["請問"],
            "ㄊㄞˋㄏㄠˇㄌㄜ˙": ["太好了"],
            "ㄐㄧㄚ ㄧㄡˊ": ["加油"],
            "ㄍㄨㄥ ㄒㄧˇ": ["恭喜"],
            
            // 更多地名
            "ㄊㄞˊㄅㄟˇ": ["台北"],
            "ㄊㄞˊㄓㄨㄥ": ["台中"],
            "ㄊㄞˊㄋㄢˊ": ["台南"],
            "ㄍㄠ ㄒㄩㄥˊ": ["高雄"],
            "ㄊㄞˊㄨㄢ": ["台灣"],
            
            // 程式相關
            "ㄔㄥˊㄕˋ": ["程式"],
            "ㄗ ㄌㄧㄠˋ": ["資料"],
            "ㄗ ㄌㄧㄠˋㄎㄨˋ": ["資料庫"],
            "ㄨㄤˇㄌㄨˋ": ["網路"],
            "ㄖㄨㄢˇㄊㄧˇ": ["軟體"],
            "ㄒㄧˋㄊㄨㄥˇ": ["系統"],
            "ㄕㄨ ㄖㄨˋㄈㄚˇ": ["輸入法"],
        ]
        rebuildNormalizedIndex()
    }

    private func normalizeTone(_ bopomofo: String) -> String {
        return String(bopomofo.filter { !toneMarks.contains($0) })
    }

    private func rebuildNormalizedIndex() {
        normalizedBopomofoDict = [:]
        for (key, words) in bopomofoDict {
            indexNormalized(key: key, words: words)
        }
    }

    private func indexNormalized(key: String, words: [String]) {
        let normalized = normalizeTone(key)
        guard !normalized.isEmpty else { return }
        if normalizedBopomofoDict[normalized] == nil {
            normalizedBopomofoDict[normalized] = []
        }
        for word in words where !(normalizedBopomofoDict[normalized]?.contains(word) ?? false) {
            normalizedBopomofoDict[normalized]?.append(word)
        }
    }

    private func toneInsensitiveCandidates(for bopomofo: String) -> [String]? {
        return normalizedBopomofoDict[normalizeTone(bopomofo)]
    }

    private func wordsForSegment(_ segment: String) -> [String] {
        var result: [String] = []
        var seen = Set<String>()

        if let exact = bopomofoDict[segment] {
            for word in exact where seen.insert(word).inserted {
                result.append(word)
            }
        }

        if let relaxed = toneInsensitiveCandidates(for: segment) {
            for word in relaxed where seen.insert(word).inserted {
                result.append(word)
            }
        }

        return result
    }

    /// 以資料陣列載入（供 ResourceManager 使用）
    func loadMappings(_ pairs: [(chinese: String, bopomofo: String)]) {
        for (ch, bp) in pairs {
            addMapping(bopomofo: bp, chinese: ch)
        }
    }
    
    /// 將注音轉換為中文候選詞
    /// - Parameter bopomofo: 注音字串
    /// - Returns: 候選中文詞及其分數
    func convert(_ bopomofo: String) -> [(word: String, score: Double)] {
        // 嘗試直接查找完整的注音
        if let candidates = bopomofoDict[bopomofo] {
            return candidates.map { word in
                let logp = ngramModel.unigramLogProbability(word)
                return (word, exp(logp))
            }.sorted { $0.score > $1.score }
        }

        // 聲調寬鬆匹配（同音不同聲調可先上字）
        if let relaxed = toneInsensitiveCandidates(for: bopomofo) {
            return relaxed.map { word in
                let logp = ngramModel.unigramLogProbability(word)
                return (word, exp(logp))
            }.sorted { $0.score > $1.score }
        }
        
        // 如果找不到，嘗試 beam 轉換
        return beamConvert(bopomofo, context: [])
    }
    
    /// 帶上下文的注音轉換
    /// - Parameters:
    ///   - bopomofo: 注音字串
    ///   - context: 前面的上下文詞
    /// - Returns: 候選中文詞及其分數
    func convertWithContext(_ bopomofo: String, context: [String]) -> [(word: String, score: Double)] {
        if let candidates = bopomofoDict[bopomofo] {
            // 使用 N-gram 模型計算上下文機率
            let results = ngramModel.predictNext(context: context, candidates: candidates)
            
            return results.map { (word: $0.word, score: $0.probability) }
        }

        if let relaxed = toneInsensitiveCandidates(for: bopomofo) {
            let results = ngramModel.predictNext(context: context, candidates: relaxed)
            return results.map { (word: $0.word, score: $0.probability) }
        }

        return beamConvert(bopomofo, context: context)
    }
    
    /// 分段並轉換注音（動態規劃）
    private func segmentAndConvert(_ bopomofo: String) -> [(word: String, score: Double)] {
        let length = bopomofo.count
        guard length > 0 else { return [] }
        
        // dp[i] 表示前 i 個字符的最佳轉換結果
        var dp: [[ConversionNode]] = Array(repeating: [], count: length + 1)
        dp[0] = [ConversionNode(word: "", score: 1.0, path: [])]
        
        let chars = Array(bopomofo)
        
        for i in 1...length {
            for j in 0..<i {
                let segment = String(chars[j..<i])
                
                if let candidates = bopomofoDict[segment] {
                    for candidate in candidates {
                        let logp = ngramModel.unigramLogProbability(candidate)
                        for prevNode in dp[j] {
                            let newScore = prevNode.score * exp(logp)
                            let newPath = prevNode.path + [candidate]
                            let newNode = ConversionNode(word: candidate, score: newScore, path: newPath)
                            dp[i].append(newNode)
                        }
                    }
                }
            }
            
            // 保留分數最高的前 10 個節點（剪枝）
            dp[i].sort { $0.score > $1.score }
            if dp[i].count > 10 {
                dp[i] = Array(dp[i].prefix(10))
            }
        }
        
        // 返回最終結果
        return dp[length].map { node in
            let fullWord = node.path.joined()
            return (word: fullWord, score: node.score)
        }
    }
    
    /// 使用 Viterbi 演算法找出最佳轉換路徑
    func viterbiConvert(_ bopomofoSequence: [String]) -> [String] {
        guard !bopomofoSequence.isEmpty else { return [] }
        
        // 狀態：每個位置可能的中文字
        var states: [[State]] = []
        
        // 初始化第一個字的狀態
        if let firstCandidates = bopomofoDict[bopomofoSequence[0]] {
            states.append(firstCandidates.map { candidate in
                let logp = ngramModel.unigramLogProbability(candidate)
                return State(word: candidate, probability: exp(logp), backpointer: nil)
            })
        } else {
            return []
        }
        
        // 動態規劃計算後續狀態
        for i in 1..<bopomofoSequence.count {
            guard let candidates = bopomofoDict[bopomofoSequence[i]] else {
                continue
            }
            
            var currentStates: [State] = []
            
            for candidate in candidates {
                var maxProb = 0.0
                var bestPrev: State?
                
                // 找出前一個狀態中轉移到當前狀態機率最大的
                for prevState in states[i-1] {
                    let transLogProb = ngramModel.bigramLogProbability(prevState.word, candidate)
                    let totalProb = prevState.probability * exp(transLogProb)
                    
                    if totalProb > maxProb {
                        maxProb = totalProb
                        bestPrev = prevState
                    }
                }
                
                if let best = bestPrev {
                    currentStates.append(State(word: candidate, probability: maxProb, backpointer: best))
                }
            }
            
            states.append(currentStates)
        }
        
        // 回溯找出最佳路徑
        guard let lastStates = states.last,
              let bestFinal = lastStates.max(by: { $0.probability < $1.probability }) else {
            return []
        }
        
        var result: [String] = []
        var current: State? = bestFinal
        
        while let state = current {
            result.insert(state.word, at: 0)
            current = state.backpointer
        }
        
        return result
    }

    /// Beam search（log 域），在未知映射或長序列時更穩定
    private func beamConvert(_ bopomofo: String, context: [String], beamWidth: Int = 8) -> [(word: String, score: Double)] {
        let chars = Array(bopomofo)
        let n = chars.count
        guard n > 0 else { return [] }
        struct BeamState { let idx: Int; let logp: Double; let path: [String] }
        var beams: [BeamState] = [BeamState(idx: 0, logp: 0.0, path: [])]
        for i in 0..<n {
            var next: [BeamState] = []
            for b in beams {
                if b.idx != i { continue }
                // 嘗試擴展不同長度的片段
                for j in (i+1)...n {
                    let seg = String(chars[i..<j])
                    let words = wordsForSegment(seg)
                    guard !words.isEmpty else { continue }
                    for w in words {
                        let lp: Double
                        if let last = b.path.last {
                            lp = b.logp + ngramModel.bigramLogProbability(last, w)
                        } else if context.last != nil {
                            lp = b.logp + ngramModel.bigramLogProbability(context.last!, w)
                        } else {
                            lp = b.logp + ngramModel.unigramLogProbability(w)
                        }
                        next.append(BeamState(idx: j, logp: lp, path: b.path + [w]))
                    }
                }
            }
            next.sort { $0.logp > $1.logp }
            if next.count > beamWidth { next = Array(next.prefix(beamWidth)) }
            beams = next
        }
        // 回收完成到末尾的序列
        let finals = beams.filter { $0.idx == n }
        let results = finals.map { (word: $0.path.joined(), score: exp($0.logp)) }
        return results.sorted { $0.score > $1.score }
    }
    
    /// 添加自定義注音映射
    func addMapping(bopomofo: String, chinese: String) {
        if bopomofoDict[bopomofo] != nil {
            if !bopomofoDict[bopomofo]!.contains(chinese) {
                bopomofoDict[bopomofo]!.append(chinese)
            }
        } else {
            bopomofoDict[bopomofo] = [chinese]
        }
        indexNormalized(key: bopomofo, words: [chinese])
    }
    
    /// 從檔案加載注音詞典
    func loadDictionary(from path: String) throws {
        let content = try String(contentsOfFile: path, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let parts = line.components(separatedBy: "\t")
            guard parts.count >= 2 else { continue }
            
            let chinese = parts[0]
            let bopomofo = parts[1]
            addMapping(bopomofo: bopomofo, chinese: chinese)
        }
    }
}

// MARK: - Helper Structures

private struct ConversionNode {
    let word: String
    let score: Double
    let path: [String]
}

private class State {
    let word: String
    let probability: Double
    let backpointer: State?
    
    init(word: String, probability: Double, backpointer: State?) {
        self.word = word
        self.probability = probability
        self.backpointer = backpointer
    }
}
