import SwiftUI
import SwiftData

struct PlayersView: View {
    let club: Club
    @Query(sort: \Player.name) private var allPlayers: [Player]
    @Query private var allGames: [MatchGame]
    @Query private var allEntries: [StatEntry]
    @State private var adding = false
    private var players: [Player] { allPlayers.filter { $0.clubID == club.id } }
    var body: some View {
        NavigationStack {
            List {
                ForEach(players) { player in
                    NavigationLink {
                        PlayerDetailsView(player: player, games: allGames.filter { $0.clubID == club.id }, entries: allEntries)
                    } label: {
                        HStack(spacing: 12) {
                            Text("\(player.overall)")
                                .font(.title2.bold()).monospacedDigit()
                                .frame(width: 52, height: 52)
                                .background(.mint.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading) {
                                Text(player.name).font(.headline)
                                Text("#\(player.number) • \(player.position)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 4)
                    }
                }
            }
            .overlay {
                if players.isEmpty { EmptyHint(title: "Aucun joueur", subtitle: "Ajoute tes amis pour former ton effectif.") }
            }
            .navigationTitle("Effectif")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { adding = true } label: { Image(systemName: "plus") } } }
            .sheet(isPresented: $adding) { PlayerEditorView(clubID: club.id) }
        }
    }
}

struct PlayerEditorView: View {
    let clubID: UUID
    var player: Player? = nil
    @Environment(\.modelContext) private var context
    @State private var saveError: String?
    private func saveChanges() -> Bool {
        do { try context.save(); return true }
        catch { context.rollback(); saveError = "Sauvegarde impossible : \(error.localizedDescription)"; return false }
    }
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var position = "WR"
    @State private var number = 0
    @State private var overall = 75

    var body: some View {
        NavigationStack {
            Form {
                Section("Identité") {
                    TextField("Prénom / surnom", text: $name)
                    Stepper("Numéro : \(number)", value: $number, in: 0...99)
                    Picker("Position", selection: $position) {
                        ForEach(Position.allCases) { Text($0.rawValue).tag($0.rawValue) }
                    }
                }
                Section("Évaluation du gérant") {
                    HStack { Text("Overall"); Spacer(); Text("\(overall)").font(.title2.bold()).foregroundStyle(.mint) }
                    Slider(value: Binding(get: { Double(overall) }, set: { overall = Int($0) }), in: 1...99, step: 1)
                    Text("L'overall est manuel et n'évolue pas automatiquement dans la V1.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(player == nil ? "Nouveau joueur" : "Modifier joueur")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let player {
                            player.name = cleanName; player.position = position
                            player.number = number; player.overall = overall
                        } else {
                            context.insert(Player(clubID: clubID, name: cleanName, position: position,
                                                  number: number, overall: overall))
                        }
                        if saveChanges() { dismiss() }
                    }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let player {
                    name = player.name; position = player.position
                    number = player.number; overall = player.overall
                }
            }
        }
        .alert("Erreur de sauvegarde", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: { Text(saveError ?? "") }

    }
}

struct PlayerDetailsView: View {
    let player: Player
    let games: [MatchGame]
    let entries: [StatEntry]
    @State private var editing = false
    @State private var selectedSeason: UUID?
    @Query(sort: \Season.createdAt, order: .reverse) private var allSeasons: [Season]
    private var seasons: [Season] { allSeasons.filter { $0.clubID == player.clubID } }
    private var filteredGames: [MatchGame] { games.filter { selectedSeason == nil || $0.seasonID == selectedSeason } }
    private var totals: PlayerTotals { Totals.forPlayer(player.id, games: filteredGames, entries: entries) }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Picker("Période", selection: $selectedSeason) {
                    Text("Carrière").tag(UUID?.none)
                    ForEach(seasons) { Text($0.name).tag(Optional($0.id)) }
                }
                PlayerCard(player: player, totals: totals)
                HStack(spacing: 12) {
                    LabelValue(label: "Matchs", value: "\(totals.appearances)")
                    LabelValue(label: "Victoires", value: "\(totals.wins)")
                    LabelValue(label: "Interceptions", value: "\(totals.interceptions)")
                }
                .padding().background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 12) {
                    Text(selectedSeason == nil ? "Statistiques de carrière" : "Statistiques de saison").font(.headline)
                    LabeledContent("Passes TD", value: "\(totals.passTD)")
                    LabeledContent("TD sur réception", value: "\(totals.receivingTD)")
                    LabeledContent("TD au sol", value: "\(totals.rushingTD)")
                    LabeledContent("Conversions", value: "\(totals.conversions)")
                }.padding().background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 16))
            }.padding()
        }
        .navigationTitle(player.name)
        .toolbar { Button("Modifier") { editing = true } }
        .sheet(isPresented: $editing) {
            // Editing preserves player ID, stats and group membership.
            PlayerEditorView(clubID: player.clubID, player: player)
        }
    }
}

struct PlayerCard: View {
    let player: Player
    let totals: PlayerTotals
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("GAMESPLIT • FICHE JOUEUR").font(.caption2.bold()).tracking(2).foregroundStyle(.mint)
                    Text(player.name).font(.system(size: 27, weight: .heavy, design: .rounded))
                    Text("#\(player.number)   •   \(player.position)").foregroundStyle(.white.opacity(0.75))
                }
                Spacer()
                VStack {
                    Text("\(player.overall)").font(.system(size: 46, weight: .black, design: .rounded))
                    Text("OVR").font(.caption.bold())
                }.foregroundStyle(.yellow)
            }
            HStack {
                LabelValue(label: "PASSES TD", value: "\(totals.passTD)")
                LabelValue(label: "TOUCHDOWNS", value: "\(totals.touchdowns)")
                LabelValue(label: "INT", value: "\(totals.interceptions)")
            }
        }
        .foregroundStyle(.white)
        .padding(24)
        .background(LinearGradient(colors: [Color(red: 0.06, green: 0.19, blue: 0.32),
                                            Color(red: 0.06, green: 0.29, blue: 0.27)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 20))
    }
}
