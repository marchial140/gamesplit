import SwiftUI
import SwiftData

@MainActor
struct StandingsView: View {
    let club: Club
    @Query private var allPlayers: [Player]
    @Query private var allGames: [MatchGame]
    @Query private var allEntries: [StatEntry]
    @Query(sort: \Season.createdAt, order: .reverse) private var allSeasons: [Season]
    @State private var positionFilter = "Toutes"
    @State private var metric = RankingMetric.contribution
    @State private var selectedSeason: UUID?
    @State private var showingNewSeason = false
    @State private var initialized = false
    private var players: [Player] { allPlayers.filter { $0.clubID == club.id && (positionFilter == "Toutes" || $0.positions.contains(positionFilter)) } }
    private var seasons: [Season] { allSeasons.filter { $0.clubID == club.id } }
    private var games: [MatchGame] {
        allGames.filter { $0.clubID == club.id && $0.isFinished && (selectedSeason == nil || $0.seasonID == selectedSeason) }
    }
    private var ranks: [(player: Player, stats: PlayerTotals)] {
        let totals = Totals.byPlayer(games: games, entries: allEntries)
        return players.map { (player: $0, stats: totals[$0.id] ?? PlayerTotals()) }
            .filter { PerformanceEligibility.hasPerformance($0.stats) }
            .sorted {
                if metric.value($0.stats) != metric.value($1.stats) {
                    return metric == .thrownInterceptions ? metric.value($0.stats) < metric.value($1.stats) : metric.value($0.stats) > metric.value($1.stats)
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
    @State private var planning = false
    var body: some View {
        let ranked = ranks
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    SportHeading(title: "Les performances parlent", subtitle: "Matchs terminés • statistiques réellement enregistrées")
                    filters
                    if ranked.isEmpty {
                        SportEmptyState(symbol: "trophy", title: "Le classement vous attend", message: "Aucun joueur avec un match terminé pour ces filtres. Enregistrez un résultat ou changez la période.", actionTitle: "Planifier un match", action: { planning = true })
                    } else {
                        SportHeading(title: "Le podium", subtitle: metric.rawValue)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
                            ForEach(0..<min(3, ranked.count), id: \.self) { index in
                                let item = ranked[index]
                                NavigationLink {
                                    PlayerDetailsView(player: item.player, games: allGames.filter { $0.clubID == club.id }, entries: allEntries)
                                } label: {
                                    PodiumCard(player: item.player, stats: item.stats, rank: index + 1, metric: metric)
                                }.buttonStyle(.plain)
                            }
                        }
                        SportHeading(title: "Dans le détail")
                        VStack(spacing: 16) {
                            ForEach(ranked.indices, id: \.self) { index in
                                let item = ranked[index]
                                NavigationLink {
                                    PlayerDetailsView(player: item.player, games: allGames.filter { $0.clubID == club.id }, entries: allEntries)
                                } label: {
                                    HStack(spacing: 12) {
                                        Text("\(index + 1)").font(.headline.monospacedDigit()).foregroundStyle(.secondary).frame(minWidth: 22)
                                        SportAvatar(data: item.player.photoData, name: item.player.name, size: 42)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.player.name).font(.headline).foregroundStyle(.primary)
                                            Text("\(item.player.positionLabel) • \(item.player.overall) OVR").font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer(minLength: 0)
                                        Text("\(metric.value(item.stats))").font(.title3.bold().monospacedDigit()).foregroundStyle(SportTheme.accent)
                                    }
                                }.buttonStyle(.plain)
                                if index < ranked.count - 1 { Divider() }
                            }
                        }.sportPanel()
                        ShareLink(item: textLeaderboard) { Label("Partager le classement", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.buttonStyle(.bordered)
                    }
                    Text("Contribution GameSplit : TD marqué ×6, passe TD ×\(ContributionRules.passingTouchdown), interception défensive ×2, conversion ×1. Indicateur ludique, distinct du score réel.").font(.caption).foregroundStyle(.secondary)
                }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 24)
            }
            .background(SportTheme.background)
            .navigationTitle("Classements")
            .toolbar { Button { showingNewSeason = true } label: { Label("Nouvelle saison", systemImage: "calendar.badge.plus") } }
            .onAppear { if !initialized { selectedSeason = seasons.first?.id; initialized = true } }
            .sheet(isPresented: $showingNewSeason, onDismiss: { selectedSeason = seasons.first?.id }) { NewSeasonView(clubID: club.id) }
            .sheet(isPresented: $planning) { MatchPlanningSheet(club: club) }
        }
    }
    private var filters: some View {
        VStack(spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack { seasonPicker; positionPicker }
                VStack(alignment: .leading) { seasonPicker; positionPicker }
            }
            Picker("Classer par", selection: $metric) {
                ForEach(RankingMetric.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading)
        }.foregroundStyle(.primary).sportPanel()
    }
    private var seasonPicker: some View {
        Picker("Période", selection: $selectedSeason) {
            Text("Carrière").tag(UUID?.none)
            ForEach(seasons) { Text($0.name).tag(Optional($0.id)) }
        }.pickerStyle(.menu)
    }
    private var positionPicker: some View {
        Picker("Position", selection: $positionFilter) {
            Text("Toutes").tag("Toutes")
            ForEach(Position.allCases) { Text($0.rawValue).tag($0.rawValue) }
        }.pickerStyle(.menu)
    }
}

@MainActor
struct PodiumCard: View {
    let player: Player
    let stats: PlayerTotals
    let rank: Int
    let metric: RankingMetric
    @Query private var teams: [Team]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("\(rank)", systemImage: rank == 1 ? "crown.fill" : "medal.fill").font(.headline).foregroundStyle(SportTheme.performanceInk)
                Spacer(minLength: 0)
                Text("\(player.overall) OVR").font(.caption.bold()).foregroundStyle(.secondary)
            }
            SportAvatar(data: player.photoData, name: player.name, size: 64)
            Text(player.name).font(.headline).foregroundStyle(.primary)
            Text(player.positionLabel).font(.caption.bold()).foregroundStyle(SportTheme.accent)
            Text(teams.filter { $0.clubID == player.clubID && $0.memberIDs.contains(player.id) }.map(\.name).joined(separator: " • "))
                .font(.caption).foregroundStyle(.secondary)
            Text("\(metric.value(stats))").font(.system(.largeTitle, design: .rounded).weight(.heavy)).foregroundStyle(SportTheme.performanceInk)
            PrimaryStats(position: player.position, totals: stats)
        }.frame(maxWidth: .infinity, alignment: .leading).sportPanel()
    }
}

@MainActor
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
    case passingYards = "Verges par la passe"
    case receivingYards = "Verges de réception"
    case receptions = "Réceptions"
    case thrownInterceptions = "Interceptions lancées (moins = mieux)"
    case tackles = "Plaqués"
    case sacks = "Sacs du quart"
    var id: String { rawValue }
    func value(_ totals: PlayerTotals) -> Int {
        switch self {
        case .contribution: return totals.contributionPoints
        case .touchdowns: return totals.touchdowns
        case .passing: return totals.passTD
        case .interceptions: return totals.interceptions
        case .passingYards: return totals.passingYards
        case .receivingYards: return totals.receivingYards
        case .receptions: return totals.receptions
        case .thrownInterceptions: return totals.thrownInterceptions
        case .tackles: return totals.tackles
        case .sacks: return totals.sacks
        }
    }
}
