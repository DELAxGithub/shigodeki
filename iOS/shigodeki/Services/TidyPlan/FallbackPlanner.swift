import Foundation

struct FallbackPlanner {
    static func generatePlan(locale: UserLocale = UserLocale(country: "CA", city: "Toronto")) -> Plan {
        let tasks = [
            createSellTask(),
            createRecycleTask(),
            createGiveTask()
        ]
        return Plan(
            project: "Fallback Moving Plan",
            locale: locale,
            tasks: tasks
        )
    }
    
    private static func createSellTask() -> TidyTask {
        TidyTask(
            id: "FB01",
            title: "大型家電を出品する（テレビ等）",
            area: "リビング",
            exit_tag: .sell,
            priority: 4,
            effort_min: 30,
            labels: ["売却", "家電"],
            checklist: [
                "背面で型番を確認する",
                "正面・側面・背面・型番ラベルを撮影",
                "直近の相場を調べる",
                "フリマサイトに出品する"
            ],
            links: ["https://www.facebook.com/marketplace/"],
            url: "https://www.facebook.com/marketplace/",
            due_at: DateHelper.futureDate(days: 3)
        )
    }
    
    private static func createRecycleTask() -> TidyTask {
        TidyTask(
            id: "RC01",
            title: "不要なケーブルを束ねて資源回収へ",
            area: "電子機器",
            exit_tag: .recycle,
            priority: 2,
            effort_min: 15,
            labels: ["リサイクル", "ケーブル"],
            checklist: [
                "使っていないケーブルを集める",
                "最寄りの回収拠点を調べる",
                "持ち込み日時を決める"
            ],
            links: ["https://www.toronto.ca/services-payments/recycling-organics-garbage/waste-wizard/"],
            url: nil,
            due_at: DateHelper.futureDate(days: 7)
        )
    }
    
    private static func createGiveTask() -> TidyTask {
        TidyTask(
            id: "GV01",
            title: "本・雑誌を譲渡/寄付する",
            area: "書籍",
            exit_tag: .give,
            priority: 2,
            effort_min: 20,
            labels: ["譲渡", "本"],
            checklist: [
                "状態で仕分けする",
                "良品は地域グループに投稿",
                "残りはブックポスト等へ寄付"
            ],
            links: ["https://www.facebook.com/groups/"],
            url: nil,
            due_at: DateHelper.futureDate(days: 5)
        )
    }
}

private struct DateHelper {
    static func futureDate(days: Int) -> String {
        let futureDate = Date().addingTimeInterval(86400 * TimeInterval(days))
        return ISO8601DateFormatter().string(from: futureDate)
    }
}
