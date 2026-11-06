import SwiftUI
import SwiftData

struct StandingsView: View {
    let club: Club
    @Query private var allPlayers: [Player]
    @Query private var allGames: [MatchGame]
    @Query private var allEntries: [StatEntry]
    @Query(sort: \Season.createdAt, order: .reverse) private var allSeasons: [Season]
    @State private var metric = RankingMetric.contribution
    @State private var selectedSeason: UUID?
    @State private var showingNewSeason = false
    private var players: [Player] { allPlayers.filter { $0.clubID == club.id } }
    private var seasons: [Season] { allSeasons.filter { $0.clubID == club.id } }
    private var games: [MatchGame] {
        allGames.filter { $0.clubID == club.id && (selectedSeason == nil || $0.seasonID == selectedSeason) }
    }
    private var ranks: [(player: Player, stats: PlayerTotals)] {
        players.map { (player: $0, stats: Totals.forPlayer($0.id, games: games, entries: allEntries)) }
            .sorted {
                if metric.value($0.stats) != metric.value($1.stats) {
                    return metric.value($0.stats) > metric.value($1.stats)
                }
                return $0.player.name < $1.player.name
            }
    }
    private var textLeaderboard: String {
        let seasonName = seasons.first(where: { $0.id == selectedSeason })?.name ?? "Carrière"
        let lines = ranks.enumerated().map { i, item in
            "\(i + 1). \(item.player.name) — \(metric.value(item.stats)) \(metric.rawValue) (\(item.stats.touchdowns) TD)"
        }.joined(separator: "\n")
        return "🏈 GameSplit — \(club.name) — \(seasonName)\n\(lines)"
    }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Période", selection: $selectedSeason) {
                        Text("Toutes les saisons").tag(UUID?.none)
                        ForEach(seasons) { season in Text(season.name).tag(Optional(season.id)) }
                    }
                    Button { showingNewSeason = true } label: { Label("Créer une saison", systemImage: "plus.circle") }
                }
                Section {
                    Picker("Classer par", selection: $metric) {
                        ForEach(RankingMetric.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
                Section("Classement — \(metric.rawValue)") {
                    if ranks.isEmpty { Text("Aucun joueur pour l'instant.").foregroundStyle(.secondary) }
                    ForEach(ranks.indices, id: \.self) { i in
                        let item = ranks[i]
                        HStack(spacing: 12) {
                            Text("\(i + 1)").font(.headline).foregroundStyle(i == 0 ? Color.orange : Color.secondary).frame(width: 26)
                            VStack(alignment: .leading) {
                                Text(item.player.name).font(.headline)
                                Text("\(item.player.position) • \(item.player.overall) OVR")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("\(metric.value(item.stats))").font(.headline).monospacedDigit()
                                Text("\(item.stats.touchdowns) TD • \(item.stats.interceptions) INT")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section("Règles de calcul") {
                    Text("TD marqués : 6 points • Passe TD : 2 points • Interception défensive : 2 points • Conversion : 1 point. Ce classement ludique n'est pas le score officiel des matchs.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    ShareLink(item: textLeaderboard) {
                        Label("Partager le classement", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .navigationTitle("Statistiques")
            .onAppear { if selectedSeason == nil { selectedSeason = seasons.first?.id } }
            .sheet(isPresented: $showingNewSeason, onDismiss: { selectedSeason = seasons.first?.id }) { NewSeasonView(clubID: club.id) }
        }


    }
}

struct NewSeasonView: View {
    let clubID: UUID
    @Environment(\.modelContext) private var context
    @State private var saveError: String?
    private func saveChanges() -> Bool {
        do { try context.save(); return true }
        catch { context.rollback(); saveError = "Sauvegarde impossible : \(error.localizedDescription)"; return false }
    }
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    var body: some View {
        NavigationStack {
            Form { TextField("Ex. Automne 2027", text: $name) }
                .navigationTitle("Nouvelle saison")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Créer") {
                            context.insert(Season(clubID: clubID, name: name.trimmingCharacters(in: .whitespacesAndNewlines)))
                            if saveChanges() { dismiss() }
                        }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
        }
        .alert("Erreur de sauvegarde", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: { Text(saveError ?? "") }

    }
}

enum RankingMetric: String, CaseIterable, Identifiable {
    case contribution = "Contribution GameSplit (non officielle)"
    case touchdowns = "TD marqués"
    case passing = "Passes TD"
    case interceptions = "Interceptions"
    var id: String { rawValue }
    func value(_ totals: PlayerTotals) -> Int {
        switch self {
        case .contribution: return totals.contributionPoints
        case .touchdowns: return totals.touchdowns
        case .passing: return totals.passTD
        case .interceptions: return totals.interceptions
        }
    }
}
