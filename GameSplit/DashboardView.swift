import SwiftUI
import SwiftData

struct DashboardView: View {
    let club: Club
    @Query private var players: [Player]
    @Query private var games: [MatchGame]
    @Query private var seasons: [Season]
    @Query private var entries: [StatEntry]
    private var clubPlayers: [Player] { players.filter { $0.clubID == club.id } }
    private var clubGames: [MatchGame] { games.filter { $0.clubID == club.id } }
    private var activeSeason: Season? { seasons.filter { $0.clubID == club.id }.sorted { $0.createdAt > $1.createdAt }.first }
    private var seasonGames: [MatchGame] {
        guard let season = activeSeason else { return [] }
        return clubGames.filter { $0.seasonID == season.id }
    }
    private var leaders: [Player] {
        clubPlayers.sorted {
            Totals.forPlayer($0.id, games: seasonGames, entries: entries).contributionPoints >
            Totals.forPlayer($1.id, games: seasonGames, entries: entries).contributionPoints
        }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(club.name).font(.title.bold())
                        Text("Flag / touch football • \(activeSeason?.name ?? "Saison")")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        LabelValue(label: "Joueurs", value: "\(clubPlayers.count)")
                        LabelValue(label: "Matchs", value: "\(seasonGames.count)")
                        LabelValue(label: "Terminés", value: "\(seasonGames.filter(\.isFinished).count)")
                    }.padding().background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 16))
                    if let next = seasonGames.filter({ !$0.isFinished }).sorted(by: { $0.date < $1.date }).first {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Prochain match", systemImage: "calendar").font(.headline)
                            Text(next.date.formatted(date: .abbreviated, time: .shortened)).font(.title3.bold())
                            Text(next.venue.isEmpty ? "Lieu à confirmer" : next.venue).foregroundStyle(.secondary)
                            Text("\(next.participants.count) participants • \(next.costPerPlayer, format: .currency(code: "CAD")) / joueur")
                                .font(.subheadline)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                         .padding().background(.mint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Meilleurs joueurs", systemImage: "trophy.fill").font(.headline)
                        if leaders.isEmpty { Text("Ajoute des joueurs pour commencer.").foregroundStyle(.secondary) }
                        ForEach(0..<min(3, leaders.count), id: \.self) { index in
                            let player = leaders[index]
                            let points = Totals.forPlayer(player.id, games: seasonGames, entries: entries).contributionPoints
                            HStack {
                                Text("\(index + 1).").foregroundStyle(.secondary).frame(width: 26)
                                Text(player.name).bold()
                                Spacer()
                                Text("\(points) pts").monospacedDigit()
                            }
                        }
                    }.padding().background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 16))
                    Text("Les points du classement sont des points de contribution GameSplit, pas les points officiels du match.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding()
            }.navigationTitle("Accueil")
            .toolbar { NavigationLink("Sauvegarde") { BackupView() } }
        }
    }
}
