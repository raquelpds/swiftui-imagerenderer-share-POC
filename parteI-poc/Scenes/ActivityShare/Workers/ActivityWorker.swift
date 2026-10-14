import Foundation

// MARK: - Worker (Workers/ActivityWorker.swift)
// Não é mais usado pelo Interactor (os dados vêm do ActivityShareDraft).
// Mantido para criar o Draft de teste no @main e para previews.
protocol ActivityWorkerProtocol {
    func fetchLastActivity() -> ActivitySummary
}

struct MockActivityWorker: ActivityWorkerProtocol {
    func fetchLastActivity() -> ActivitySummary {
        ActivitySummary(
            title: "Atividade X",
            durationInSeconds: 25 * 60 + 43, // 25:43
            score: 850,
            completedChallenges: 12
        )
    }
}
