import Foundation

// MARK: - Interactor (Scenes/ActivityShare/ActivityShareInteractor.swift)

// Protocolo: o que a View pode pedir ao Interactor
@MainActor
protocol ActivityShareBusinessLogic {
    func loadActivity(request: ActivityShare.LoadActivity.Request)
    func selectBackground(request: ActivityShare.SelectBackground.Request)
}

@MainActor
final class ActivityShareInteractor: ActivityShareBusinessLogic {
    var presenter: ActivitySharePresentationLogic?
    private let draft: ActivityShareDraft

    init(draft: ActivityShareDraft) {
        self.draft = draft
    }

    func loadActivity(request: ActivityShare.LoadActivity.Request) {
        presenter?.presentActivity(
            response: .init(
                activity: draft.activity,
                backgroundImageData: draft.photoData
            )
        )
    }

    func selectBackground(request: ActivityShare.SelectBackground.Request) {
        draft.photoData = request.imageData
        loadActivity(request: .init())   // reapresenta o card com a foto nova
    }
}
