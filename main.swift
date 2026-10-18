import SwiftUI
import AppKit
import ServiceManagement

// 맥을 실제로 쓰는 시간만 세다가, 정한 간격이 차면 화면 위에 점안 알림 창을 띄운다.
final class Model: ObservableObject {
    static let shared = Model()
    let d: UserDefaults

    @Published var intervalMin: Int { didSet { d.set(intervalMin, forKey: "intervalMin") } }
    @Published var dailyCap: Int { didSet { d.set(dailyCap, forKey: "dailyCap") } }
    @Published var count: Int { didSet { d.set(count, forKey: "count"); history[day] = count } }
    @Published var history: [String: Int] { didSet { d.set(history, forKey: "history") } }  // "yyyy-MM-dd": 그날 횟수
    @Published var day: String { didSet { d.set(day, forKey: "day") } }
    @Published var activeSec: Double = 0
    @Published var lastDrop: Date? { didSet { d.set(lastDrop, forKey: "lastDrop") } }
    var snoozeUntil = Date.distantPast
    let idleLimit: Double = 120  // 2분 넘게 입력이 없으면 자리 비움으로 보고 안 센다

    init(_ d: UserDefaults = .standard) {
        self.d = d
        intervalMin = d.object(forKey: "intervalMin") as? Int ?? 60
        dailyCap = d.object(forKey: "dailyCap") as? Int ?? 6
        count = d.integer(forKey: "count")
        day = d.string(forKey: "day") ?? Model.today()
        lastDrop = d.object(forKey: "lastDrop") as? Date
        history = d.dictionary(forKey: "history") as? [String: Int] ?? [:]
        if count > 0 { history[day] = count }
    }

    // 기록 키는 지역 달력(불기, 일본 연호, 아랍 숫자 등)과 무관하게 항상 양력 yyyy-MM-dd 로 쓴다.
    static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    static func today(_ now: Date = Date()) -> String { keyFormatter.string(from: now) }

    var remainingMin: Int { max(0, Int((Double(intervalMin * 60) - activeSec) / 60)) }
    var capReached: Bool { count >= dailyCap }

    /// 주기마다 호출. 알림을 띄워야 하면 true.
    func tick(elapsed: Double, idle: Double, now: Date = Date()) -> Bool {
        rollover(now)
        if idle < idleLimit { activeSec += elapsed }
        return activeSec >= Double(intervalMin * 60) && !capReached && now >= snoozeUntil
    }

    /// 날짜가 바뀌었으면 오늘 횟수를 0부터 다시 센다. 기록, 표시 전에 항상 먼저 부른다.
    func rollover(_ now: Date = Date()) {
        let t = Model.today(now)
        if t != day { day = t; count = 0; activeSec = 0 }
    }

    func logDrop(_ now: Date = Date()) { rollover(now); count += 1; activeSec = 0; lastDrop = Date(); Reminder.hide() }
    func snooze(_ min: Int) { snoozeUntil = Date().addingTimeInterval(Double(min * 60)); Reminder.hide() }
}

// 화면 문구. 맥 언어 설정(첫 번째 선호 언어)을 따르고, 없는 언어는 영어로 보여 준다.
let langs = ["en", "ko", "ja", "de", "zh"]
let strings: [String: [String]] = [
    //           en, ko, ja, de, zh(간체)
    "title":    ["💧 Time for eye drops", "💧 인공눈물 넣을 시간", "💧 目薬の時間です", "💧 Zeit für Augentropfen", "💧 该滴眼药水了"],
    "today":    ["Today %d/%d", "오늘 %d/%d회", "今日 %d/%d回", "Heute %d/%d", "今天 %d/%d 次"],
    "done":     ["Done", "넣었어요", "さしました", "Erledigt", "已滴"],
    "later":    ["In %d min", "%d분 뒤", "%d分後", "In %d Min.", "%d 分钟后"],
    "last":     ["Last drops %@", "마지막 점안 %@", "前回 %@", "Zuletzt getropft %@", "上次滴眼 %@"],
    "capped":   ["Daily limit reached, reminders paused", "오늘 상한에 도달해 알림을 멈췄어요", "今日の上限に達したため通知を停止しました", "Tageslimit erreicht, Erinnerungen pausiert", "已达今日上限，提醒已暂停"],
    "next":     ["Next reminder after %d min of screen time", "다음 알림까지 화면 사용 %d분", "次の通知まで画面使用 %d分", "Nächste Erinnerung nach %d Min. Bildschirmzeit", "再使用屏幕 %d 分钟后提醒"],
    "now":      ["💧 I just used drops", "💧 지금 넣었어요", "💧 今さしました", "💧 Gerade getropft", "💧 刚刚滴过"],
    "preview":  ["Preview reminder", "알림 미리보기", "通知をプレビュー", "Erinnerung testen", "预览提醒"],
    "interval": ["Interval", "알림 간격", "通知間隔", "Intervall", "提醒间隔"],
    "min":      ["%d min", "%d분", "%d分", "%d Min.", "%d 分钟"],
    "cap":      ["Daily limit %d", "하루 상한 %d회", "1日の上限 %d回", "Tageslimit %d", "每日上限 %d 次"],
    "login":    ["Launch at login", "로그인 시 자동 실행", "ログイン時に起動", "Bei Anmeldung starten", "登录时启动"],
    "reset":    ["Reset today", "오늘 기록 초기화", "今日の記録をリセット", "Heute zurücksetzen", "重置今日记录"],
    "quit":     ["Quit", "종료", "終了", "Beenden", "退出"],
    "settings": ["Settings…", "설정…", "設定…", "Einstellungen…", "设置…"],
    "settingsTitle": ["Settings", "설정", "設定", "Einstellungen", "设置"],
    "feedback": ["Feedback", "피드백", "フィードバック", "Feedback", "反馈"],
    "history":  ["History", "점안 기록", "点眼の記録", "Verlauf", "滴眼记录"],
    "historySum": ["%d drops on %d days in the last 20 weeks", "최근 20주 동안 %d회, %d일 기록", "直近20週で %d回、%d日記録", "%d-mal an %d Tagen in den letzten 20 Wochen", "最近 20 周共 %d 次，记录 %d 天"],
    "dayTip":   ["%@: %d", "%@: %d회", "%@: %d回", "%@: %d", "%@: %d 次"],
    "fbSubject": ["TearTime feedback", "인공눈물 타이머 피드백", "TearTime フィードバック", "TearTime Feedback", "TearTime 反馈"],
]
let langIndex: Int = {
    let p = Locale.preferredLanguages.first ?? "en"
    return langs.firstIndex { p.hasPrefix($0) } ?? 0
}()
func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: strings[key]![langIndex], arguments: args)
}

enum Reminder {
    static var panel: NSPanel?

    static func show() {
        guard panel == nil, let screen = NSScreen.main else { return }
        let size = NSSize(width: 360, height: 150)
        let p = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.contentView = NSHostingView(rootView: ReminderView().environmentObject(Model.shared))
        let f = screen.visibleFrame
        p.setFrameOrigin(NSPoint(x: f.midX - size.width / 2, y: f.maxY - size.height - 24))
        p.orderFrontRegardless()
        NSSound(named: "Glass")?.play()
        panel = p
    }

    static func hide() { panel?.orderOut(nil); panel = nil }
}

struct ReminderView: View {
    @EnvironmentObject var m: Model
    var body: some View {
        VStack(spacing: 12) {
            Text(L("title")).font(.title3.bold())
            Text(L("today", m.count, m.dailyCap)).foregroundStyle(.secondary)
            HStack {
                Button(L("done")) { m.logDrop() }.keyboardShortcut(.defaultAction)
                Button(L("later", 10)) { m.snooze(10) }
                Button(L("later", 30)) { m.snooze(30) }
            }
        }
        .padding(20)
        .frame(width: 360, height: 150)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct MenuView: View {
    @EnvironmentObject var m: Model
    @Environment(\.openWindow) var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("today", m.count, m.dailyCap)).font(.headline)
                .foregroundStyle(m.capReached ? .red : .primary)
            if let t = m.lastDrop {
                Text(L("last", t.formatted(date: .omitted, time: .shortened))).foregroundStyle(.secondary)
            }
            Text(m.capReached ? L("capped") : L("next", m.remainingMin))
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button(L("now")) { m.logDrop() }
                Button(L("preview")) { Reminder.show() }
            }
            Divider()
            HStack {
                Button(L("settings")) { NSApp.activate(); openWindow(id: "settings") }
                Button(L("feedback")) { sendFeedback() }
                Spacer()
                Button(L("quit")) { NSApp.terminate(nil) }
            }
        }
        .padding(14)
        .frame(width: 300)
        .onAppear { m.rollover() }
    }
}

struct SettingsView: View {
    @EnvironmentObject var m: Model
    @State var atLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Picker(L("interval"), selection: $m.intervalMin) {
                ForEach([20, 30, 45, 60, 90, 120], id: \.self) { Text(L("min", $0)).tag($0) }
            }
            Stepper(L("cap", m.dailyCap), value: $m.dailyCap, in: 1...12)
            Toggle(L("login"), isOn: $atLogin)
                .onChange(of: atLogin) { _, on in
                    try? on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                    atLogin = SMAppService.mainApp.status == .enabled
                }
            Button(L("reset")) { m.count = 0; m.activeSec = 0 }
            Section(L("history")) { HistoryGrid().environmentObject(m) }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// 깃허브 잔디처럼 최근 20주를 하루 한 칸으로 보여 준다. 진할수록 많이 넣은 날, 주황은 상한을 넘긴 날.
struct HistoryGrid: View {
    @EnvironmentObject var m: Model
    let weeks = 20, cell: CGFloat = 13, gap: CGFloat = 3

    var body: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let back = (cal.component(.weekday, from: today) - cal.firstWeekday + 7) % 7
        let start = cal.date(byAdding: .day, value: -back - (weeks - 1) * 7, to: today)!
        let days = (0..<weeks * 7).map { cal.date(byAdding: .day, value: $0, to: start)! }
        let shown = days.filter { $0 <= today }.map { m.history[Model.today($0)] ?? 0 }

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: gap) {
                ForEach(0..<weeks, id: \.self) { w in
                    VStack(spacing: gap) {
                        ForEach(0..<7, id: \.self) { r in
                            let day = days[w * 7 + r]
                            let n = m.history[Model.today(day)] ?? 0
                            RoundedRectangle(cornerRadius: 3)
                                .fill(day > today ? .clear : color(n))
                                .frame(width: cell, height: cell)
                                .help(L("dayTip", day.formatted(date: .abbreviated, time: .omitted), n))
                        }
                    }
                }
            }
            Text(L("historySum", shown.reduce(0, +), shown.filter { $0 > 0 }.count))
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    func color(_ n: Int) -> Color {
        if n == 0 { return .gray.opacity(0.18) }
        if n > m.dailyCap { return .orange }
        let r = Double(n) / Double(max(1, m.dailyCap))
        return .green.opacity(r <= 0.34 ? 0.35 : r <= 0.67 ? 0.6 : 0.9)
    }
}

// 피드백은 기본 메일 앱으로 보낸다. 받는 주소는 여기 한 곳만 바꾸면 된다.
let feedbackEmail = "d4ymonth@gmail.com"

func sendFeedback() {
    let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    let os = ProcessInfo.processInfo.operatingSystemVersionString
    var c = URLComponents()
    c.scheme = "mailto"
    c.path = feedbackEmail
    c.queryItems = [URLQueryItem(name: "subject", value: L("fbSubject")),
                    URLQueryItem(name: "body", value: "\n\n\n---\nTearTime \(v) / macOS \(os) / \(Locale.preferredLanguages.first ?? "")")]
    if let url = c.url { NSWorkspace.shared.open(url) }
}

@main
struct TearTimeApp: App {
    @StateObject var m = Model.shared
    init() {
        if CommandLine.arguments.contains("--selftest") { selfTest(); exit(0) }
        _ = TearTimeApp.ticker
        if CommandLine.arguments.contains("--preview") { DispatchQueue.main.async { Reminder.show() } }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuView().environmentObject(m)
        } label: {
            Image(systemName: "drop.fill")  // 메뉴바 폭 최소화: 물방울 하나만
        }
        .menuBarExtraStyle(.window)

        Window(L("settingsTitle"), id: "settings") {
            SettingsView().environmentObject(m)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
    }
}

// MenuBarExtra 내용은 메뉴를 열 때만 그려져서 onReceive가 안 돈다. 타이머는 앱 시작 시 따로 건다.
extension TearTimeApp {
    // 타이머가 늦게 불려도(App Nap, 부하) 실제 흐른 시간을 센다. 잠자기 같은 긴 공백은 최대 2분만 인정.
    static var lastTick = Date()
    static let ticker: Timer = {
        let t = Timer(timeInterval: 30, repeats: true) { _ in
            let now = Date()
            let elapsed = min(max(0, now.timeIntervalSince(lastTick)), Model.shared.idleLimit)
            lastTick = now
            let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState,
                                                                eventType: CGEventType(rawValue: ~0)!)
            if Model.shared.tick(elapsed: elapsed, idle: idle, now: now) { Reminder.show() }
        }
        RunLoop.main.add(t, forMode: .common)
        return t
    }()
}

func selfTest() {
    let m = Model(UserDefaults(suiteName: "teartime.selftest")!)
    m.intervalMin = 60; m.dailyCap = 2; m.count = 0; m.activeSec = 0; m.day = Model.today()
    let now = Date()
    precondition(!m.tick(elapsed: 3000, idle: 0, now: now))          // 50분: 아직
    precondition(!m.tick(elapsed: 3000, idle: 500, now: now))        // 자리 비움: 안 셈
    precondition(m.tick(elapsed: 600, idle: 0, now: now))            // 60분: 알림
    m.count = 2
    precondition(!m.tick(elapsed: 30, idle: 0, now: now))            // 상한 도달: 알림 없음
    precondition(!m.tick(elapsed: 0, idle: 0, now: now.addingTimeInterval(86400)) && m.count == 0) // 다음 날 초기화
    m.history = [:]; m.count = 3
    precondition(m.history[m.day] == 3)                               // 횟수 바뀌면 그날 기록에 남음
    m.day = Model.today(now.addingTimeInterval(-86400)); m.count = 4  // 어제 4회인 상태에서
    m.logDrop(now)                                                    // 자정 지나 첫 tick 전에 넣으면
    precondition(m.day == Model.today(now) && m.count == 1 && m.history[m.day] == 1)  // 오늘 1회로 기록
    precondition(Model.today(Date(timeIntervalSince1970: 1_767_312_000)) == "2026-01-02")  // 달력 설정과 무관한 양력 키
    for (k, v) in strings {                                           // 언어별 서식 자리표시자가 같아야 함
        let spec = { (t: String) in t.components(separatedBy: "%").dropFirst().map { $0.prefix(1) } }
        precondition(v.allSatisfy { spec($0) == spec(v[0]) }, "placeholder mismatch: \(k)")
    }
    precondition(strings.values.allSatisfy { $0.count == langs.count })   // 모든 문구가 5개 언어를 다 가짐
    print(L("title"), L("today", 3, 6), L("next", 42))
    print("selftest ok")
}
