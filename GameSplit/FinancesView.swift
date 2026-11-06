import SwiftUI
import SwiftData

struct FinancesView: View {
    let club: Club
    @Query(sort: \MatchGame.date, order: .reverse) private var allGames: [MatchGame]
    @Query private var allPlayers: [Player]
    private var games: [MatchGame] { allGames.filter { $0.clubID == club.id } }
    private var total: Double { games.reduce(0) { $0 + $1.totalCost } }
    private var collected: Double { games.reduce(0) {
        $0 + $1.costPerPlayer * Double($1.paidIDs.intersection($1.participants).count)
    } }
    var body: some View {
        NavigationStack {
            List {
                Section("Sommaire") {
                    LabeledContent("Coûts des parties", value: total, format: .currency(code: "CAD"))
                    LabeledContent("Reçu", value: collected, format: .currency(code: "CAD"))
                    LabeledContent("Reste à recevoir", value: max(0, total - collected), format: .currency(code: "CAD"))
                }
                Section("Par match") {
                    if games.isEmpty { Text("Aucune partie enregistrée.").foregroundStyle(.secondary) }
                    ForEach(games) { game in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(game.date.formatted(date: .abbreviated, time: .omitted)).font(.headline)
                            LabeledContent("Coût", value: game.totalCost, format: .currency(code: "CAD"))
                            LabeledContent("Par joueur", value: game.costPerPlayer, format: .currency(code: "CAD"))
                            Text("Payé : \(game.paidIDs.intersection(game.participants).count)/\(game.participants.count) participants")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 5)
                    }
                }
                Section {
                    Text("Paiements suivis manuellement. GameSplit n'envoie pas de virements et n'accède pas aux comptes bancaires.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.navigationTitle("Coûts et paiements")
        }
    }
}
