import SwiftUI
public import Combine

// MARK: - View (Scenes/ActivityShare/View/ActivityShareView.swift)

// Protocolo: o que o Presenter pode pedir à View
@MainActor
protocol ActivityShareDisplayLogic: AnyObject {
    func displayActivity(viewModel: ActivityShare.LoadActivity.ViewModel)
}

// Item usado pelo .sheet(item:) do share sheet
struct ShareItem: Identifiable {
    let id = UUID()
    let activityItems: [Any]
}

// Estado da tela + ponte entre Presenter e SwiftUI
//É essa View que o presenter enxerga
@MainActor
final class ActivityShareStore: ObservableObject, ActivityShareDisplayLogic {
    @Published private(set) var card: ActivityCardViewModel?
    @Published private(set) var generatedImage: UIImage?
    @Published private(set) var errorMessage: String?
    @Published private(set) var saveMessage: String?
    @Published private(set) var shareMessage: String?
    @Published var shareItem: ShareItem?            // sem private(set): a View faz binding

    var interactor: ActivityShareBusinessLogic?

    // MARK: - Gerar imagem

    func didTapGenerate() {
        resetMessages()
        generatedImage = nil
        interactor?.loadActivity(request: .init())
    }

    // Chamado pelo Presenter
    func displayActivity(viewModel: ActivityShare.LoadActivity.ViewModel) {
        card = viewModel.card
        renderImage(from: viewModel.card)
    }

    private func renderImage(from card: ActivityCardViewModel) {
        let template = ActivityShareCardView(viewModel: card)

        guard let image = ShareImageRenderer.render(template) else {
            errorMessage = "Não foi possível gerar a imagem."
            return
        }

        // Validação da POC
        print("size (pt):", image.size)       // esperado: (360.0, 640.0)
        print("scale:", image.scale)          // esperado: 3.0
        print("pixels:", image.size.width * image.scale,
              "x", image.size.height * image.scale) // esperado: 1080 x 1920

        generatedImage = image
    }

    // MARK: - Foto de fundo

    func didCapturePhoto(_ data: Data) {
        resetMessages()
        interactor?.selectBackground(request: .init(imageData: data))
    }

    // MARK: - Salvar na galeria

    func didTapSave() {
        guard let image = generatedImage else { return }
        saveMessage = nil

        Task {
            do {
                try await PhotoLibrarySaver.save(image)
                saveMessage = "Imagem salva na galeria."
            } catch {
                saveMessage = "Não foi possível salvar. Verifique a permissão de fotos."
            }
        }
    }

    // MARK: - Share sheet

    func didTapShare() {
        guard let image = generatedImage else { return }
        shareMessage = nil

        do {
            let items = try ShareService.activityItems(for: image, mode: .file)
            shareItem = ShareItem(activityItems: items)
        } catch {
            errorMessage = "Não foi possível preparar a imagem para compartilhar."
        }
    }

    func didFinishSharing(completed: Bool) {
        shareItem = nil
        shareMessage = completed ? "Imagem compartilhada." : nil
    }

    private func resetMessages() {
        errorMessage = nil
        saveMessage = nil
        shareMessage = nil
    }
}

struct ActivityShareView: View {
    @StateObject private var store: ActivityShareStore
    @State private var showCamera = false

    init(store: ActivityShareStore) {
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Tirar foto", systemImage: "camera")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!CameraPicker.isAvailable)

                    Button("Gerar imagem") {
                        store.didTapGenerate()
                    }
                    .buttonStyle(.borderedProminent)
                }

                if !CameraPicker.isAvailable {
                    Text("Câmera indisponível neste dispositivo (use um iPhone real).")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                if let error = store.errorMessage {
                    Text(error).foregroundColor(.red)
                }

                if let image = store.generatedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 400)
                        .cornerRadius(12)
                        .shadow(radius: 8)

                    VStack(spacing: 12) {
                        Button {
                            store.didTapShare()
                        } label: {
                            Label("Compartilhar", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            store.didTapSave()
                        } label: {
                            Label("Salvar na galeria", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.bordered)
                    }

                    if let message = store.saveMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }

                    if let message = store.shareMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
        .sheet(item: $store.shareItem) { item in
            ActivityShareSheet(items: item.activityItems) { completed in
                store.didFinishSharing(completed: completed)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { data in
                showCamera = false
                if let data {
                    store.didCapturePhoto(data)
                }
            }
            .ignoresSafeArea()
        }
    }
}
