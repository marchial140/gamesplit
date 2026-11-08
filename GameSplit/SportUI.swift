import SwiftUI
import SwiftData
import PhotosUI
import UIKit

enum SportTheme {
    static let navy = Color(red: 0.06, green: 0.10, blue: 0.20)
    static let electric = Color(red: 0.10, green: 0.36, blue: 0.88)
    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.43, green: 0.67, blue: 1, alpha: 1) : UIColor(red: 0.10, green: 0.36, blue: 0.88, alpha: 1)
    })
    static let orange = Color(red: 0.96, green: 0.43, blue: 0.14)
    static let performanceInk = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 1, green: 0.69, blue: 0.40, alpha: 1) : UIColor(red: 0.68, green: 0.24, blue: 0.02, alpha: 1)
    })
    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
}

@MainActor
struct SportPanel: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(18).background(SportTheme.surface, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.primary.opacity(0.07), lineWidth: 1))
    }
}

extension View {
    @MainActor func sportPanel() -> some View { modifier(SportPanel()) }
}

@MainActor
struct SportHeading: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.title2.bold()).foregroundStyle(.primary)
            if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

@MainActor
struct SportEmptyState: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbol).font(.system(size: 34, weight: .semibold))
                .foregroundStyle(SportTheme.accent).padding(22)
                .background(SportTheme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 24))
                .accessibilityHidden(true)
            Text(title).font(.title2.bold()).multilineTextAlignment(.center)
            Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(action: action) { Label(actionTitle, systemImage: "plus.circle.fill").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 7) }
                    .buttonStyle(.borderedProminent).tint(SportTheme.accent)
            }
        }.frame(maxWidth: .infinity).padding(.vertical, 24).sportPanel()
    }
}

@MainActor
struct PrimaryStats: View {
    let position: String
    let totals: PlayerTotals
    var onDark = false
    private var items: [(String, Int)] {
        switch position {
        case "QB": return [("Passes TD", totals.passTD), ("Verges passe", totals.passingYards), ("INT lancées", totals.thrownInterceptions)]
        case "WR": return [("Réceptions", totals.receptions), ("Verges réc.", totals.receivingYards), ("TD", totals.receivingTD)]
        case "DB": return [("Interceptions", totals.interceptions), ("Plaqués", totals.tackles)]
        case "Rusher": return [("Sacs du quart", totals.sacks), ("Plaqués", totals.tackles)]
        default: return [("TD", totals.touchdowns), ("Matchs", totals.appearances), ("Victoires", totals.wins)]
        }
    }
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) { cells }
            VStack(alignment: .leading, spacing: 16) { cells }
        }
    }
    private var cells: some View {
        ForEach(items.indices, id: \.self) { index in
            VStack(alignment: .leading, spacing: 4) {
                Text("\(items[index].1)").font(.title2.bold().monospacedDigit()).foregroundStyle(onDark ? Color.white : Color.primary)
                Text(items[index].0).font(.caption).foregroundStyle(onDark ? Color.white.opacity(0.85) : Color.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
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
                        .safeAreaInset(edge: .bottom, spacing: 0) { profileSelector.padding(.horizontal, 16).padding(.vertical, 10).background(SportTheme.surface).foregroundStyle(.primary) }
                } else {
                    ScrollView {
                        VStack(spacing: 18) {
                            SportEmptyState(symbol: "person.crop.rectangle", title: "Votre terrain, votre profil", message: "Choisissez votre fiche pour retrouver vos performances. Cette sélection reste locale : ce n’est pas un compte en ligne.")
                            if !players.isEmpty { profileSelector.foregroundStyle(.primary).sportPanel() }
                            NavigationLink { PlayersView(club: club) } label: { Label("Créer ou choisir un joueur", systemImage: "person.badge.plus").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent)
                        }.padding(16).padding(.bottom, 24)
                    }.background(SportTheme.background)
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

@MainActor
struct MatchPlanningSheet: View {
    let club: Club
    var initialTeamID: UUID? = nil
    @Query(sort: \Season.createdAt, order: .reverse) private var seasons: [Season]
    @State private var addingSeason = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Group {
            if let season = seasons.first(where: { $0.clubID == club.id }) {
                NewMatchView(club: club, season: season, initialTeamID: initialTeamID)
            } else {
                NavigationStack {
                    ScrollView {
                        SportEmptyState(symbol: "calendar.badge.plus", title: "Une saison pour commencer", message: "Créez une saison pour organiser vos premiers matchs.", actionTitle: "Créer une saison", action: { addingSeason = true }).padding()
                    }
                    .background(SportTheme.background)
                    .toolbar { Button("Fermer") { dismiss() } }
                }
            }
        }
        .sheet(isPresented: $addingSeason) { NewSeasonView(clubID: club.id) }
    }
}
