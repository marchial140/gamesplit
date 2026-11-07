import SwiftUI
import SwiftData

@MainActor
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
                            SportAvatar(data: player.photoData, name: player.name)
                            Text("\(player.overall)")
                                .font(.title2.bold()).monospacedDigit()
                                .frame(width: 52, height: 52)
                                .background(.mint.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading) {
                                Text(player.name).font(.headline)
                                Text((player.hasNumber ? "#\(player.number) • " : "") + player.positionLabel)
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

@MainActor
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
    @State private var photoData: Data?
    @State private var hasNumber = true
    @State private var secondary = Set<String>()
    @State private var memberships = Set<UUID>()
    @State private var initialized = false
    @Query private var allTeams: [Team]
    private var teams: [Team] { allTeams.filter { $0.clubID == clubID } }

    var body: some View {
        NavigationStack {
            Form {
                Section("Identité") {
                    TextField("Prénom / surnom", text: $name)
                    LocalPhotoPicker(data: $photoData)
                    Toggle("Afficher un numéro", isOn: $hasNumber)
                    if hasNumber { Stepper("Numéro : \(number)", value: $number, in: 0...99) }
                    Picker("Position", selection: $position) {
                        ForEach(Position.allCases) { Text($0.rawValue).tag($0.rawValue) }
                    }
                }
                Section("Positions secondaires") {
                    ForEach(Position.allCases.filter { $0.rawValue != position }) { value in
                        Toggle(value.rawValue, isOn: Binding(get: { secondary.contains(value.rawValue) }, set: { on in
                            if on { secondary.insert(value.rawValue) } else { secondary.remove(value.rawValue) }
                        }))
                    }
                }
                Section("Équipes") {
                    if teams.isEmpty { Text("Créez des équipes depuis l’onglet Équipes.").foregroundStyle(.secondary) }
                    ForEach(teams) { team in
                        Toggle(team.name, isOn: Binding(get: { memberships.contains(team.id) }, set: { on in
                            if on { memberships.insert(team.id) } else { memberships.remove(team.id) }
                        }))
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
                        let value = player ?? Player(clubID: clubID, name: cleanName)
                        if player == nil { context.insert(value) }
                        value.name = cleanName; value.position = position
                        value.number = number; value.hasNumber = hasNumber; value.overall = overall
                        value.photoData = photoData; value.secondaryPositions = secondary.subtracting([position]).sorted().joined(separator: ",")
                        for team in teams {
                            var ids = team.memberIDs
                            if memberships.contains(team.id) { ids.insert(value.id) }
                            else { ids.remove(value.id); var captains = team.captainIDs; captains.remove(value.id); team.captainIDs = captains }
                            team.memberIDs = ids
                        }
                        if saveChanges() { dismiss() }
                    }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                guard !initialized else { return }; initialized = true
                if let player {
                    name = player.name; position = player.position
                    number = player.number; overall = player.overall
                    photoData = player.photoData; hasNumber = player.hasNumber
                    secondary = player.positions.subtracting([player.position])
                    memberships = Set(teams.filter { $0.memberIDs.contains(player.id) }.map(\.id))
                }
            }
        }
        .alert("Erreur de sauvegarde", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: { Text(saveError ?? "") }

    }
}

@MainActor
struct PlayerDetailsView: View {
    let player: Player
    let games: [MatchGame]
    let entries: [StatEntry]
    @State private var editing = false
    @Query private var allTeams: [Team]
    private var teams: [Team] { allTeams.filter { $0.clubID == player.clubID && $0.memberIDs.contains(player.id) } }
    private var history: [MatchGame] { filteredGames.filter { $0.participants.contains(player.id) }.sorted { $0.date > $1.date } }
    private var personalRecords: (passing: Int, touchdowns: Int) {
        let ids = Set(history.map(\.id))
        var passing: [UUID: Int] = [:], touchdowns: [UUID: Int] = [:]
        for entry in entries where entry.playerID == player.id && ids.contains(entry.matchID) {
            if entry.kind == StatKind.passTD.rawValue { passing[entry.matchID, default: 0] += entry.value }
            if entry.kind == StatKind.receivingTD.rawValue || entry.kind == StatKind.rushingTD.rawValue { touchdowns[entry.matchID, default: 0] += entry.value }
        }
        return (passing.values.max() ?? 0, touchdowns.values.max() ?? 0)
    }
    @State private var selectedSeason: UUID?
    @Query(sort: \Season.createdAt, order: .reverse) private var allSeasons: [Season]
    private var seasons: [Season] { allSeasons.filter { $0.clubID == player.clubID } }
    private var filteredGames: [MatchGame] { games.filter { selectedSeason == nil || $0.seasonID == selectedSeason } }
    private var totals: PlayerTotals { Totals.forPlayer(player.id, games: filteredGames, entries: entries) }

    var body: some View {
        let periodTotals = totals
        let records = personalRecords
        ScrollView {
            VStack(spacing: 18) {
                Picker("Période", selection: $selectedSeason) {
                    Text("Carrière").tag(UUID?.none)
                    ForEach(seasons) { Text($0.name).tag(Optional($0.id)) }
                }
                PlayerCard(player: player, totals: periodTotals)
                if !teams.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Équipes").font(.headline)
                        ForEach(teams) { team in
                            HStack { SportAvatar(data: team.logoData, name: team.name, size: 30); Text(team.name) }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(spacing: 12) {
                    LabelValue(label: "Matchs", value: "\(periodTotals.appearances)")
                    LabelValue(label: "Victoires", value: "\(periodTotals.wins)")
                    LabelValue(label: "Interceptions", value: "\(periodTotals.interceptions)")
                }
                .padding().background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 12) {
                    Text(selectedSeason == nil ? "Statistiques de carrière" : "Statistiques de saison").font(.headline)
                    LabeledContent("Passes TD", value: "\(periodTotals.passTD)")
                    LabeledContent("TD sur réception", value: "\(periodTotals.receivingTD)")
                    LabeledContent("TD au sol", value: "\(periodTotals.rushingTD)")
                    LabeledContent("Conversions", value: "\(periodTotals.conversions)")
                    LabeledContent("Verges par la passe", value: "\(periodTotals.passingYards)")
                    LabeledContent("Interceptions lancées", value: "\(periodTotals.thrownInterceptions)")
                    LabeledContent("Réceptions (TD inclus)", value: "\(periodTotals.receptions)")
                    LabeledContent("Verges de réception", value: "\(periodTotals.receivingYards)")
                    LabeledContent("Plaqués", value: "\(periodTotals.tackles)")
                    LabeledContent("Sacs du quart", value: "\(periodTotals.sacks)")
                    LabeledContent("Contribution (non officielle)", value: "\(periodTotals.contributionPoints)")
                }.padding().background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 12) {
                    Text("Meilleures performances — période choisie").font(.headline)
                    LabeledContent("Passes TD en un match", value: "\(records.passing)")
                    LabeledContent("TD marqués en un match", value: "\(records.touchdowns)")
                    Text("Historique des matchs").font(.headline)
                    if history.isEmpty { Text("Aucun match pour cette période.").foregroundStyle(.secondary) }
                    ForEach(history) { game in
                        NavigationLink { MatchDetailsView(game: game) } label: { MatchRow(game: game) }
                        Divider()
                    }
                }.padding().background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 16))
                ShareLink(item: "GameSplit — \(player.name)\n\(player.positionLabel) • \(player.overall) OVR\n\(periodTotals.appearances) matchs • \(periodTotals.passTD) passes TD • \(periodTotals.touchdowns) TD marqués") {
                    Label("Partager mes performances", systemImage: "square.and.arrow.up")
                }
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

@MainActor
struct PlayerCard: View {
    let player: Player
    let totals: PlayerTotals
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                SportAvatar(data: player.photoData, name: player.name, size: 64)
                VStack(alignment: .leading, spacing: 5) {
                    Text("GAMESPLIT • FICHE JOUEUR").font(.caption2.bold()).tracking(2).foregroundStyle(.mint)
                    Text(player.name).font(.system(size: 27, weight: .heavy, design: .rounded))
                    Text((player.hasNumber ? "#\(player.number) • " : "") + player.positionLabel).foregroundStyle(.white.opacity(0.75))
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
        .background(LinearGradient(colors: [SportTheme.navy,
                                            SportTheme.accent],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 20))
    }
}
