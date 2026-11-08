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
                                .background(SportTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
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
                    HStack { Text("Overall"); Spacer(); Text("\(overall)").font(.title2.bold()).foregroundStyle(SportTheme.accent) }
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
    private var records: [PerformanceRecord] { PersonalRecords.best(playerID: player.id, games: filteredGames, entries: entries) }
    @State private var selectedSeason: UUID?
    @Query(sort: \Season.createdAt, order: .reverse) private var allSeasons: [Season]
    private var seasons: [Season] { allSeasons.filter { $0.clubID == player.clubID } }
    private var filteredGames: [MatchGame] { games.filter { selectedSeason == nil || $0.seasonID == selectedSeason } }
    private var totals: PlayerTotals { Totals.forPlayer(player.id, games: filteredGames, entries: entries) }

    @State private var showingAllStats = false
    var body: some View {
        let periodTotals = totals
        let bests = records
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Picker("Période", selection: $selectedSeason) {
                    Text("Carrière").tag(UUID?.none)
                    ForEach(seasons) { Text($0.name).tag(Optional($0.id)) }
                }.pickerStyle(.menu).foregroundStyle(.primary).tint(SportTheme.accent)
                    .frame(maxWidth: .infinity, alignment: .leading).sportPanel()
                PlayerCard(player: player, totals: periodTotals)
                if !teams.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(teams) { team in
                                HStack(spacing: 8) {
                                    SportAvatar(data: team.logoData, name: team.name, size: 32)
                                    Text(team.name).font(.subheadline.bold())
                                }.padding(10).background(SportTheme.surface, in: Capsule())
                            }
                        }
                    }
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { participationStats(periodTotals) }
                    VStack(alignment: .leading, spacing: 12) { participationStats(periodTotals) }
                }.sportPanel()
                DisclosureGroup(isExpanded: $showingAllStats) {
                    VStack(spacing: 12) {
                        LabeledContent("Passes TD", value: "\(periodTotals.passTD)")
                        LabeledContent("TD sur réception", value: "\(periodTotals.receivingTD)")
                        LabeledContent("TD au sol", value: "\(periodTotals.rushingTD)")
                        LabeledContent("Conversions", value: "\(periodTotals.conversions)")
                        LabeledContent("Verges par la passe", value: "\(periodTotals.passingYards)")
                        LabeledContent("Interceptions lancées", value: "\(periodTotals.thrownInterceptions)")
                        LabeledContent("Réceptions (TD inclus)", value: "\(periodTotals.receptions)")
                        LabeledContent("Verges de réception", value: "\(periodTotals.receivingYards)")
                        LabeledContent("Interceptions défensives", value: "\(periodTotals.interceptions)")
                        LabeledContent("Plaqués", value: "\(periodTotals.tackles)")
                        LabeledContent("Sacs du quart", value: "\(periodTotals.sacks)")
                        LabeledContent("Contribution non officielle", value: "\(periodTotals.contributionPoints)")
                    }.font(.subheadline).padding(.top, 16)
                } label: {
                    Label("Toutes les statistiques", systemImage: "chart.bar.fill").font(.headline)
                }.sportPanel()
                if !bests.isEmpty {
                    SportHeading(title: "Votre marque sur le terrain", subtitle: "Records par match terminé • période sélectionnée")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                        ForEach(bests) { record in
                            VStack(alignment: .leading, spacing: 10) {
                                Image(systemName: "bolt.fill").foregroundStyle(SportTheme.performanceInk)
                                Text("\(record.value)").font(.system(.largeTitle, design: .rounded).weight(.heavy)).foregroundStyle(SportTheme.performanceInk)
                                Text(record.kind.title).font(.caption.bold())
                            }.frame(maxWidth: .infinity, alignment: .leading).sportPanel()
                        }
                    }
                }
                SportHeading(title: "Au fil des matchs")
                if history.isEmpty {
                    SportEmptyState(symbol: "sportscourt", title: "Le prochain chapitre vous attend", message: "Les matchs de ce joueur apparaîtront ici dès qu’il sera ajouté aux participants.")
                } else {
                    ForEach(history) { game in
                        NavigationLink { MatchDetailsView(game: game) } label: { MatchRow(game: game).sportPanel() }.buttonStyle(.plain)
                    }
                }
                ShareLink(item: "GameSplit — \(player.name)\n\(player.positionLabel) • \(player.overall) OVR\n\(periodTotals.appearances) matchs • \(periodTotals.passTD) passes TD • \(periodTotals.touchdowns) TD marqués") {
                    Label("Partager mes performances", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                }.buttonStyle(.bordered)
            }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 24)
        }
        .background(SportTheme.background)
        .navigationTitle(player.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Modifier") { editing = true } }
        .sheet(isPresented: $editing) { PlayerEditorView(clubID: player.clubID, player: player) }
    }
    private func participationStats(_ totals: PlayerTotals) -> some View {
        Group {
            LabelValue(label: "Matchs", value: "\(totals.appearances)")
            LabelValue(label: "Victoires", value: "\(totals.wins)")
            LabelValue(label: "Positions", value: "\(player.positions.count)")
        }
    }
}

@MainActor
struct PlayerCard: View {
    let player: Player
    let totals: PlayerTotals
    @ScaledMetric(relativeTo: .title) private var photoSize: CGFloat = 92
    @ScaledMetric(relativeTo: .largeTitle) private var ratingSize: CGFloat = 64
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                SportAvatar(data: player.photoData, name: player.name, size: min(photoSize, 120))
                    .overlay(RoundedRectangle(cornerRadius: min(photoSize, 120) * 0.28).strokeBorder(.white.opacity(0.25), lineWidth: 2))
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(player.overall)").font(.system(size: min(ratingSize, 96), weight: .black, design: .rounded)).foregroundStyle(.yellow)
                    Text("OVR MANUEL").font(.caption2.bold()).foregroundStyle(.white.opacity(0.85))
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("GAMESPLIT • ATHLÈTE").font(.caption2.bold()).tracking(2).foregroundStyle(.white.opacity(0.85))
                Text(player.name).font(.system(.largeTitle, design: .rounded).weight(.heavy)).foregroundStyle(.white)
                HStack(alignment: .firstTextBaseline) {
                    Text(player.position).font(.subheadline.bold()).padding(.horizontal, 10).padding(.vertical, 5)
                        .background(SportTheme.navy.opacity(0.65), in: Capsule())
                    if player.hasNumber { Text("#\(player.number)").font(.subheadline.bold()) }
                }.foregroundStyle(.white)
                if player.positions.count > 1 {
                    Text(player.positions.subtracting([player.position]).sorted().joined(separator: " • ")).font(.caption).foregroundStyle(.white.opacity(0.85))
                }
            }
            Rectangle().fill(.white.opacity(0.25)).frame(height: 1)
            PrimaryStats(position: player.position, totals: totals, onDark: true)
        }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [SportTheme.navy, SportTheme.electric], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 26))
    }
}
