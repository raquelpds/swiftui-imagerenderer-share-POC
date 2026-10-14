import Foundation

// MARK: - Entity (Entities/ActivitySummary.swift)
// Dado de negócio da atividade. A foto de fundo NÃO fica aqui:
// ela é escolha do usuário e vive no ActivityShareDraft.
struct ActivitySummary {
    let title: String
    let durationInSeconds: Int
    let score: Int
    let completedChallenges: Int
}
