import SwiftUI

// MARK: - Configurator (Scenes/ActivityShare/ActivityShareConfigurator.swift)
// View -> Interactor -> Presenter -> View
enum ActivityShareConfigurator {
    @MainActor
    static func makeView(draft: ActivityShareDraft) -> ActivityShareView {
        let store = ActivityShareStore()                       // View
        let interactor = ActivityShareInteractor(draft: draft)
        let presenter = ActivitySharePresenter()

        store.interactor = interactor
        interactor.presenter = presenter
        presenter.view = store                                 // weak

        return ActivityShareView(store: store)
    }
}
