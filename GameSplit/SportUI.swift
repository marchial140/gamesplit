import SwiftUI
import SwiftData
import PhotosUI
import UIKit

enum SportTheme {
    static let navy = Color(red: 0.06, green: 0.10, blue: 0.20)
    static let accent = Color(red: 0.10, green: 0.36, blue: 0.88)
    static let orange = Color(red: 0.95, green: 0.43, blue: 0.14)
}

@MainActor
struct SportAvatar: View {
    let data: Data?
    let name: String
    var size: CGFloat = 52
    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Text(String(name.prefix(2)).uppercased()).font(.system(size: size * 0.32, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white).frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(SportTheme.navy.gradient)
            }
        }
        .frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: size * 0.28))
        .accessibilityLabel("Photo de \(name)")
    }
}

@MainActor
struct LocalPhotoPicker: View {
    @Binding var data: Data?
    @State private var selection: PhotosPickerItem?
    @State private var errorMessage: String?
    @State private var loading = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SportAvatar(data: data, name: "GS", size: 72)
                PhotosPicker(selection: $selection, matching: .images) {
                    Label(loading ? "Chargement…" : "Choisir une photo", systemImage: "photo")
                }.disabled(loading)
            }
            if data != nil { Button("Retirer la photo", role: .destructive) { data = nil; selection = nil } }
        }
        .task(id: selection) {
            guard let selection else { return }
            loading = true
            defer { loading = false }
            do {
                guard let bytes = try await selection.loadTransferable(type: Data.self),
                      bytes.count <= 25_000_000, let image = UIImage(data: bytes),
                      image.size.width > 0, image.size.height > 0 else { throw BackupError.invalid }
                try Task.checkCancellation()
                let scale = min(1, 512 / max(image.size.width, image.size.height))
                let format = UIGraphicsImageRendererFormat(); format.scale = 1
                let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                    image.draw(in: CGRect(origin: .zero, size: size))
                }
                data = resized.jpegData(compressionQuality: 0.8)
            } catch is CancellationError { }
            catch { errorMessage = "Impossible de charger cette photo. Choisissez une autre image de moins de 25 Mo." }
        }
        .alert("Photo", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }
}

@MainActor
struct PositionBadge: View {
    let position: String
    var body: some View {
        Text(position).font(.caption.bold()).padding(.horizontal, 9).padding(.vertical, 5)
            .foregroundStyle(SportTheme.accent).background(SportTheme.accent.opacity(0.1), in: Capsule())
    }
}

@MainActor
struct LocalProfileView: View {
    @Bindable var club: Club
    @Environment(\.modelContext) private var context
    @Query(sort: \Player.name) private var allPlayers: [Player]
    @Query private var games: [MatchGame]
    @Query private var entries: [StatEntry]
    @State private var errorMessage: String?
    private var players: [Player] { allPlayers.filter { $0.clubID == club.id } }
    var body: some View {
        NavigationStack {
            Group {
                if let player = players.first(where: { $0.id == club.localProfileID }) {
                    PlayerDetailsView(player: player, games: games.filter { $0.clubID == club.id }, entries: entries)
                        .safeAreaInset(edge: .bottom) { profileSelector.padding().background(.regularMaterial) }
                } else {
                    Form {
                        Section("Votre fiche sur cet appareil") {
                            Text("Choisissez votre joueur pour accéder à sa fiche. Cette sélection locale n’est pas un compte ni une connexion.")
                            profileSelector
                        }
                        NavigationLink("Créer un joueur ou gérer l’effectif") { PlayersView(club: club) }
                    }
                    .navigationTitle("Mon profil")
                }
            }
        }
        .alert("Sauvegarde", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }
    private var profileSelector: some View {
        Picker("Fiche locale", selection: Binding(get: { club.localProfileID }, set: { id in
            club.localProfileID = id
            do { try context.save() } catch { context.rollback(); errorMessage = error.localizedDescription }
        })) {
            Text("Choisir un joueur").tag(UUID?.none)
            ForEach(players) { Text($0.name).tag(Optional($0.id)) }
        }
    }
}
