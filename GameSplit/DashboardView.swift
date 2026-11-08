import SwiftUI
import SwiftData

@MainActor
struct DashboardView: View {
    let club: Club
    @Query private var players: [Player]
    @Query(sort: \MatchGame.date, order: .reverse) private var games: [MatchGame]
    @Query private var entries: [StatEntry]
    @Query private var teams: [Team]
    @State private var planning = false
    private var clubGames: [MatchGame] { games.filter { $0.clubID == club.id } }
    private var finished: [MatchGame] { clubGames.filter(\.isFinished) }
    private var weekGames: [MatchGame] {
        let week = Calendar.current.dateInterval(of: .weekOfYear, for: .now)
        return finished.filter { (week?.contains($0.date) ?? false) && $0.date <= .now }
    }
    private var next: MatchGame? { clubGames.filter { !$0.isFinished && $0.date >= .now }.min { $0.date < $1.date } }
    var body: some View {
        let weekly = Totals.byPlayer(games: weekGames, entries: entries)
        let positions = ["QB", "WR", "DB", "Rusher"].filter { position in
            players.contains { $0.clubID == club.id && $0.positions.contains(position) && PerformanceEligibility.hasPerformance(weekly[$0.id] ?? PlayerTotals(), position: position) }
        }
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    brandHeader
                    if let next {
                        SportHeading(title: "Prochain rendez-vous")
                        NavigationLink { MatchDetailsView(game: next) } label: { MatchRow(game: next).sportPanel() }.buttonStyle(.plain)
                    }
                    if finished.isEmpty {
                        SportEmptyState(symbol: "flag.checkered", title: "Votre histoire reste à écrire", message: "Un premier match, des performances à partager. Vos résultats et vos leaders apparaîtront ici, à partir de vos vraies données.", actionTitle: "Planifier un match", action: { planning = true })
                    } else {
                        SportHeading(title: "Après le coup de sifflet", subtitle: "Résultats et performances de votre collectif")
                        ForEach(Array(finished.prefix(3))) { game in
                            LocalActivityCard(game: game, players: players, entries: entries, careerGames: clubGames)
                        }
                        if !positions.isEmpty {
                            SportHeading(title: "Ils font la différence", subtitle: "Leaders de la semaine • matchs terminés")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(alignment: .top, spacing: 12) {
                                    ForEach(positions, id: \.self) { position in
                                        PositionLeaders(position: position, players: players.filter { $0.clubID == club.id && $0.positions.contains(position) }, teams: teams, totals: weekly, games: clubGames, entries: entries)
                                            .containerRelativeFrame(.horizontal, count: 6, span: 5, spacing: 12)
                                    }
                                }.padding(.bottom, 4)
                            }
                        }
                    }
                }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 24)
            }
            .background(SportTheme.background)
            .navigationTitle("Accueil")
            .toolbar { Button { planning = true } label: { Label("Planifier", systemImage: "plus") } }
            .sheet(isPresented: $planning) { MatchPlanningSheet(club: club) }
        }
    }
    private var brandHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            SportAvatar(data: nil, name: club.name, size: 54)
            VStack(alignment: .leading, spacing: 6) {
                Text("GAMESPLIT").font(.caption.bold()).tracking(3).foregroundStyle(.white.opacity(0.85))
                Text(club.name).font(.title2.bold()).foregroundStyle(.white)
                Text("Votre terrain. Votre histoire.").font(.caption).foregroundStyle(.white.opacity(0.85))
            }
            Spacer(minLength: 0)
            Image(systemName: "bolt.fill").font(.title2).foregroundStyle(SportTheme.orange).accessibilityHidden(true)
        }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [SportTheme.navy, SportTheme.electric], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24))
    }
}

@MainActor
struct PositionLeaders: View {
    let position: String
    let players: [Player]
    let teams: [Team]
    let totals: [UUID: PlayerTotals]
    let games: [MatchGame]
    let entries: [StatEntry]
    private func value(_ total: PlayerTotals) -> Int {
        switch position {
        case "QB": return total.passTD
        case "WR": return total.receivingYards
        case "DB": return total.interceptions
        default: return total.sacks
        }
    }
    var body: some View {
        let ranked = players.filter { PerformanceEligibility.hasPerformance(totals[$0.id] ?? PlayerTotals(), position: position) }.sorted {
            let left = value(totals[$0.id] ?? PlayerTotals()), right = value(totals[$1.id] ?? PlayerTotals())
            return left == right ? $0.name < $1.name : left > right
        }
        VStack(alignment: .leading, spacing: 14) {
            HStack { PositionBadge(position: position); Spacer(); Image(systemName: "bolt.fill").foregroundStyle(SportTheme.performanceInk) }
            ForEach(Array(ranked.prefix(2))) { player in
                NavigationLink { PlayerDetailsView(player: player, games: games, entries: entries) } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            SportAvatar(data: player.photoData, name: player.name, size: 44)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(player.name).font(.headline).foregroundStyle(.primary)
                                Text(teams.filter { $0.clubID == player.clubID && $0.memberIDs.contains(player.id) }.map(\.name).joined(separator: " • "))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        PrimaryStats(position: position, totals: totals[player.id] ?? PlayerTotals())
                    }
                }.buttonStyle(.plain)
            }
        }.sportPanel()
    }
}

@MainActor
struct LocalActivityCard: View {
    let game: MatchGame
    let players: [Player]
    let entries: [StatEntry]
    let careerGames: [MatchGame]
    private func newRecord(for player: Player) -> PerformanceRecord? {
        let earlier = careerGames.filter { $0.isFinished && $0.date < game.date && $0.participants.contains(player.id) }
        guard !earlier.isEmpty else { return nil }
        let previous = Dictionary(uniqueKeysWithValues: PersonalRecords.best(playerID: player.id, games: earlier, entries: entries).map { ($0.id, $0.value) })
        return PersonalRecords.best(playerID: player.id, games: [game], entries: entries).first { $0.value > (previous[$0.id] ?? 0) }
    }
    var body: some View {
        let totals = Totals.byPlayer(games: [game], entries: entries)
        let performers = players.filter { player in
            game.participants.contains(player.id) && entries.contains { $0.matchID == game.id && $0.playerID == player.id && $0.value > 0 }
        }.sorted {
            let left = totals[$0.id]?.contributionPoints ?? 0, right = totals[$1.id]?.contributionPoints ?? 0
            return left == right ? $0.name < $1.name : left > right
        }
        VStack(alignment: .leading, spacing: 16) {
            NavigationLink { MatchDetailsView(game: game) } label: { MatchRow(game: game) }.buttonStyle(.plain)
            ForEach(Array(performers.prefix(2))) { player in
                Divider()
                NavigationLink { PlayerDetailsView(player: player, games: careerGames, entries: entries) } label: {
                    HStack(alignment: .top, spacing: 12) {
                        SportAvatar(data: player.photoData, name: player.name, size: 40)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(player.name).font(.subheadline.bold()).foregroundStyle(.primary)
                            PrimaryStats(position: player.position, totals: totals[player.id] ?? PlayerTotals())
                            if let record = newRecord(for: player) {
                                Label("Record personnel : \(record.value) • \(record.kind.title)", systemImage: "bolt.fill").font(.caption.bold()).foregroundStyle(SportTheme.performanceInk)
                            }
                        }
                    }
                }.buttonStyle(.plain)
            }
        }.sportPanel()
    }
}
