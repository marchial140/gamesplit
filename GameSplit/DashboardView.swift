import SwiftUI
import SwiftData

@MainActor
struct DashboardView: View {
    let club: Club
    @Query private var players: [Player]
    @Query(sort: \MatchGame.date, order: .reverse) private var games: [MatchGame]
    @Query private var entries: [StatEntry]
    @Query private var teams: [Team]
    private var clubGames: [MatchGame] { games.filter { $0.clubID == club.id } }
    private var weekGames: [MatchGame] {
        let week = Calendar.current.dateInterval(of: .weekOfYear, for: .now)
        return clubGames.filter { $0.isFinished && (week?.contains($0.date) ?? false) && $0.date <= .now }
    }
    var body: some View {
        let weekly = Totals.byPlayer(games: weekGames, entries: entries)
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("VOTRE TERRAIN. VOTRE HISTOIRE.").font(.caption.bold()).tracking(1)
                        Text(club.name).font(.largeTitle.bold())
                        Text("Flag football • communauté locale").font(.subheadline)
                    }.foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading).padding(24)
                        .background(LinearGradient(colors: [SportTheme.navy, SportTheme.accent], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24))
                    if let next = clubGames.filter({ !$0.isFinished && $0.date >= .now }).min(by: { $0.date < $1.date }) {
                        Text("PROCHAIN RENDEZ-VOUS").font(.caption.bold()).foregroundStyle(.secondary)
                        NavigationLink { MatchDetailsView(game: next) } label: { MatchRow(game: next) }.buttonStyle(.plain)
                    }
                    Text("Leaders de la semaine").font(.title2.bold())
                    Text("Semaine civile en cours • statistiques des matchs terminés").font(.caption).foregroundStyle(.secondary)
                    ForEach(["QB", "WR", "DB", "Rusher"], id: \.self) { position in
                        PositionLeaders(position: position, players: players.filter { $0.clubID == club.id && $0.positions.contains(position) }, teams: teams, totals: weekly, games: clubGames, entries: entries)
                    }
                    Text("Sur le terrain").font(.title2.bold())
                    Text("Activités générées à partir des résultats locaux. Aucun partage entre comptes pour l’instant.").font(.caption).foregroundStyle(.secondary)
                    if clubGames.filter(\.isFinished).isEmpty { EmptyHint(title: "L’histoire commence ici", subtitle: "Terminez un match pour voir son résultat et ses performances ici.") }
                    ForEach(Array(clubGames.filter(\.isFinished).prefix(30))) { game in
                        LocalActivityCard(game: game, players: players, entries: entries, careerGames: clubGames)
                    }
                }.padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Accueil")
            .toolbar { NavigationLink("Sauvegarde", systemImage: "externaldrive") { BackupView() } }
        }
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
    private func summary(_ total: PlayerTotals) -> String {
        switch position {
        case "QB": return "\(total.passTD) passes TD • \(total.passingYards) vg • \(total.thrownInterceptions) INT lancées"
        case "WR": return "\(total.receivingYards) vg • \(total.receivingTD) TD • \(total.receptions) réc."
        case "DB": return "\(total.interceptions) INT • \(total.tackles) plaqués"
        default: return "\(total.sacks) sacs • \(total.tackles) plaqués"
        }
    }
    var body: some View {
        let ranked = players.filter { (totals[$0.id]?.appearances ?? 0) > 0 }.sorted {
            let left = value(totals[$0.id] ?? PlayerTotals()), right = value(totals[$1.id] ?? PlayerTotals())
            return left == right ? $0.name < $1.name : left > right
        }
        VStack(alignment: .leading, spacing: 12) {
            PositionBadge(position: position)
            if ranked.isEmpty { Text("Aucune performance cette semaine.").font(.caption).foregroundStyle(.secondary) }
            ForEach(Array(ranked.prefix(3))) { player in
                NavigationLink { PlayerDetailsView(player: player, games: games, entries: entries) } label: {
                    HStack(spacing: 12) {
                        SportAvatar(data: player.photoData, name: player.name, size: 44)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(player.name).font(.headline)
                            Text(summary(totals[player.id] ?? PlayerTotals())).font(.caption).foregroundStyle(.secondary)
                            Text(teams.filter { $0.clubID == player.clubID && $0.memberIDs.contains(player.id) }.map(\.name).joined(separator: " • "))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }.buttonStyle(.plain)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(16).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}

@MainActor
struct LocalActivityCard: View {
    let game: MatchGame
    let players: [Player]
    let entries: [StatEntry]
    let careerGames: [MatchGame]
    var body: some View {
        let totals = Totals.byPlayer(games: [game], entries: entries)
        let performers = players.filter { game.participants.contains($0.id) }.sorted {
            let left = totals[$0.id]?.contributionPoints ?? 0, right = totals[$1.id]?.contributionPoints ?? 0
            return left == right ? $0.name < $1.name : left > right
        }
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink { MatchDetailsView(game: game) } label: { MatchRow(game: game) }.buttonStyle(.plain)
            ForEach(Array(performers.prefix(2))) { player in
                NavigationLink { PlayerDetailsView(player: player, games: careerGames, entries: entries) } label: {
                    HStack {
                        SportAvatar(data: player.photoData, name: player.name, size: 32)
                        Text(player.name).font(.subheadline.bold())
                        Spacer()
                        Text("\(totals[player.id]?.passTD ?? 0) passes TD • \(totals[player.id]?.touchdowns ?? 0) TD").font(.caption)
                    }
                }.buttonStyle(.plain)
            }
        }.padding(16).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}
