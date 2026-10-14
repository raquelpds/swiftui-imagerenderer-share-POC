import UIKit

// MARK: - Presenter (Scenes/ActivityShare/ActivitySharePresenter.swift)

// Protocolo: o que o Interactor pode pedir ao Presenter
@MainActor
protocol ActivitySharePresentationLogic {
    func presentActivity(response: ActivityShare.LoadActivity.Response)
}

@MainActor
final class ActivitySharePresenter: ActivitySharePresentationLogic {
    weak var view: ActivityShareDisplayLogic?

    func presentActivity(response: ActivityShare.LoadActivity.Response) {
        let activity = response.activity

        let card = ActivityCardViewModel(
            title: activity.title.uppercased(),
            timeText: formatted(duration: activity.durationInSeconds),
            scoreText: scoreText(activity.score),
            challengesText: challengesText(activity.completedChallenges),
            appName: appName,
            background: background(from: response.backgroundImageData)
        )

        view?.displayActivity(viewModel: .init(card: card))
    }

    // MARK: - Formatação

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? ""
    }

    private func formatted(duration seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    private func scoreText(_ score: Int) -> String {
        score == 1 ? "1 ponto" : "\(score) pontos"
    }

    private func challengesText(_ count: Int) -> String {
        count == 1 ? "1 desafio" : "\(count) desafios"
    }

    private func background(from data: Data?) -> BackgroundSource {
        if let data, let image = UIImage(data: data) {
            return .loaded(image)
        }
        return .asset("defaultBackground")   // plano B: deixe essa imagem no Assets
    }
}
