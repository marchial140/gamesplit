import SwiftUI
import SwiftData

@MainActor
struct TeamsView: View {
    let club: Club
    @Query(sort: \Team.name) private var allTeams: [Team]
    @State private var adding = false
    private var teams: [Team] { allTeams.filter { $0.clubID == club.id } }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(teams) { team in
                        NavigationLink { TeamDetailsView(team: team, club: club) } label: {
                            HStack(spacing: 14) {
                                SportAvatar(data: team.logoData, name: team.name)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(team.name).font(.headline)
                                    Text("\(team.memberIDs.count) joueurs • \(team.captainIDs.count) capitaines")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }.padding(.vertical, 6)
                        }
                    }
                    if teams.isEmpty { Text("Créez votre première équipe, puis ajoutez ses joueurs.").foregroundStyle(.secondary) }
                } header: { Text("Vos équipes") }
                Section("Organisation • \(club.name)") {
                    NavigationLink("Tous les joueurs") { PlayersView(club: club) }
                    NavigationLink("Coûts et paiements — gestion") { FinancesView(club: club) }
                    NavigationLink("Sauvegarde locale") { BackupView() }
                    Text("Sur cet appareil, le gérant dispose de toutes les commandes. Les capitaines sont des désignations locales ; les accès individuels nécessiteront des comptes vérifiés.").font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Équipes")
            .toolbar { Button("Créer", systemImage: "plus") { adding = true } }
            .sheet(isPresented: $adding) { TeamEditorView(clubID: club.id) }
        }
    }
}

@MainActor
struct TeamEditorView: View {
    let clubID: UUID
    var team: Team? = nil
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Player.name) private var allPlayers: [Player]
    @State private var name = ""
    @State private var logoData: Data?
    @State private var members = Set<UUID>()
    @State private var captains = Set<UUID>()
    @State private var errorMessage: String?
    @State private var initialized = false
    private var players: [Player] { allPlayers.filter { $0.clubID == clubID } }
    var body: some View {
        NavigationStack {
            Form {
                Section("Identité") {
                    TextField("Nom de l’équipe", text: $name)
                    LocalPhotoPicker(data: $logoData)
                }
                Section("Effectif — plusieurs équipes possibles") {
                    if players.isEmpty { Text("Ajoutez d’abord les joueurs depuis Équipes → Tous les joueurs.") }
                    ForEach(players) { player in
                        Toggle(player.name, isOn: Binding(get: { members.contains(player.id) }, set: { included in
                            if included { members.insert(player.id) }
                            else { members.remove(player.id); captains.remove(player.id) }
                        }))
                        if members.contains(player.id) {
                            Toggle("Capitaine : \(player.name)", isOn: Binding(get: { captains.contains(player.id) }, set: { on in
                                if on { captains.insert(player.id) } else { captains.remove(player.id) }
                            })).font(.subheadline)
                        }
                    }
                }
            }
            .navigationTitle(team == nil ? "Nouvelle équipe" : "Modifier l’équipe")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        let value = team ?? Team(clubID: clubID, name: name)
                        if team == nil { context.insert(value) }
                        value.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        value.logoData = logoData; value.memberIDs = members; value.captainIDs = captains.intersection(members)
                        do { try context.save(); dismiss() }
                        catch { context.rollback(); errorMessage = error.localizedDescription }
                    }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                guard !initialized else { return }; initialized = true
                if let team { name = team.name; logoData = team.logoData; members = team.memberIDs; captains = team.captainIDs }
            }
        }
        .alert("Sauvegarde", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }
}

@MainActor
struct TeamDetailsView: View {
    let team: Team
    let club: Club
    @Query private var allPlayers: [Player]
    @Query(sort: \MatchGame.date, order: .reverse) private var allGames: [MatchGame]
    @Query private var entries: [StatEntry]
    @Query(sort: \Season.createdAt, order: .reverse) private var seasons: [Season]
    @State private var editing = false
    @State private var addingMatch = false
    private var players: [Player] { allPlayers.filter { $0.clubID == club.id && team.memberIDs.contains($0.id) }.sorted { $0.name < $1.name } }
    private func statTotal(_ kinds: Set<String>) -> Int {
        games.reduce(0) { sum, game in
            let ids = game.teamID == team.id ? game.blueIDs : game.redIDs
            return sum + entries.filter { $0.matchID == game.id && ids.contains($0.playerID) && kinds.contains($0.kind) }.reduce(0) { $0 + $1.value }
        }
    }
    private var games: [MatchGame] { allGames.filter { $0.clubID == club.id && ($0.teamID == team.id || $0.opponentTeamID == team.id) } }
    var body: some View {
        let summary = TeamRecordSummary.calculate(teamID: team.id, games: games)
        List {
            Section {
                HStack(spacing: 16) {
                    SportAvatar(data: team.logoData, name: team.name, size: 80)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(team.name).font(.title2.bold())
                        Text("\(summary.wins) V • \(summary.losses) D • \(summary.ties) N").font(.headline)
                        Text("\(summary.pointsFor) points marqués • \(summary.pointsAgainst) encaissés").font(.caption)
                    }
                }.padding(.vertical)
            }
            Section("Statistiques collectives — historique") {
                LabeledContent("Passes TD", value: "\(statTotal([StatKind.passTD.rawValue]))")
                LabeledContent("TD marqués", value: "\(statTotal([StatKind.receivingTD.rawValue, StatKind.rushingTD.rawValue]))")
                LabeledContent("Interceptions défensives", value: "\(statTotal([StatKind.interception.rawValue]))")
                LabeledContent("Verges par la passe", value: "\(statTotal([StatKind.passingYards.rawValue]))")
                LabeledContent("Plaqués", value: "\(statTotal([StatKind.tackle.rawValue]))")
                LabeledContent("Sacs du quart", value: "\(statTotal([StatKind.sack.rawValue]))")
            }
            Section("Effectif") {
                if players.isEmpty { Text("Effectif vide. Touchez Modifier pour ajouter des joueurs.") }
                ForEach(players) { player in
                    NavigationLink {
                        PlayerDetailsView(player: player, games: allGames.filter { $0.clubID == club.id }, entries: entries)
                    } label: {
                        HStack {
                            SportAvatar(data: player.photoData, name: player.name, size: 42)
                            VStack(alignment: .leading) {
                                Text(player.name).bold()
                                Text(player.positionLabel).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if team.captainIDs.contains(player.id) { Image(systemName: "c.circle.fill").accessibilityLabel("Capitaine") }
                            Text("\(player.overall)").font(.headline)
                        }
                    }
                }
            }
            Section("Calendrier et résultats") {
                Button("Planifier un match", systemImage: "plus.circle") { addingMatch = true }
                if games.isEmpty { Text("Aucun match associé à cette équipe.").foregroundStyle(.secondary) }
                ForEach(games) { game in
                    NavigationLink { MatchDetailsView(game: game) } label: { MatchRow(game: game) }
                }
            }
        }
        .navigationTitle(team.name)
        .toolbar { Button("Modifier") { editing = true } }
        .sheet(isPresented: $editing) { TeamEditorView(clubID: club.id, team: team) }
        .sheet(isPresented: $addingMatch) {
            if let season = seasons.first(where: { $0.clubID == club.id }) { NewMatchView(club: club, season: season, initialTeamID: team.id) }
            else { NavigationStack { NewSeasonView(clubID: club.id) } }
        }
    }
}

@MainActor
struct MatchRow: View {
    let game: MatchGame
    @Query private var teams: [Team]
    private var home: String { teams.first { $0.id == game.teamID }?.name ?? "Bleus" }
    private var away: String { teams.first { $0.id == game.opponentTeamID }?.name ?? (game.opponentName.isEmpty ? "Rouges" : game.opponentName) }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(game.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(game.isFinished ? "TERMINÉ" : "À VENIR").font(.caption2.bold()).foregroundStyle(SportTheme.accent)
            }
            Text("\(home)  \(game.blueScore) — \(game.redScore)  \(away)").font(.headline)
            Text(game.venue.isEmpty ? "Lieu à confirmer" : game.venue).font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 8)
    }
}
