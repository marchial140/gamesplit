import SwiftUI
import SwiftData

@MainActor
struct TeamsView: View {
    let club: Club
    @Query(sort: \Team.name) private var allTeams: [Team]
    @Query private var allGames: [MatchGame]
    @State private var adding = false
    private var teams: [Team] { allTeams.filter { $0.clubID == club.id } }
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    SportHeading(title: "Vos couleurs. Votre collectif.", subtitle: club.name)
                    if teams.isEmpty {
                        SportEmptyState(symbol: "person.3.fill", title: "Le collectif commence ici", message: "Créez votre équipe, ajoutez son logo et réunissez les joueurs.", actionTitle: "Créer une équipe", action: { adding = true })
                    }
                    ForEach(teams) { team in
                        NavigationLink { TeamDetailsView(team: team, club: club) } label: {
                            TeamSummaryCard(team: team, games: allGames.filter { $0.clubID == club.id })
                        }.buttonStyle(.plain)
                    }
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 18) {
                            NavigationLink { PlayersView(club: club) } label: { Label("Tous les joueurs", systemImage: "person.crop.rectangle.stack") }
                            NavigationLink { FinancesView(club: club) } label: { Label("Coûts et paiements", systemImage: "dollarsign.circle") }
                            NavigationLink { BackupView() } label: { Label("Sauvegarde locale", systemImage: "externaldrive") }
                            Text("Gestion sur cet appareil. Les capitaines sont des désignations locales, sans connexion en ligne.").font(.caption).foregroundStyle(.secondary)
                        }.padding(.top, 14)
                    } label: { Label("Gestion", systemImage: "slider.horizontal.3").font(.subheadline.bold()).foregroundStyle(.secondary) }
                    .sportPanel()
                }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 24)
            }
            .background(SportTheme.background)
            .navigationTitle("Équipes")
            .toolbar { Button { adding = true } label: { Label("Créer", systemImage: "plus") } }
            .sheet(isPresented: $adding) { TeamEditorView(clubID: club.id) }
        }
    }
}

@MainActor
struct TeamSummaryCard: View {
    let team: Team
    let games: [MatchGame]
    private var next: MatchGame? {
        games.filter { !$0.isFinished && $0.date >= .now && ($0.teamID == team.id || $0.opponentTeamID == team.id) }.min { $0.date < $1.date }
    }
    var body: some View {
        let summary = TeamRecordSummary.calculate(teamID: team.id, games: games)
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                SportAvatar(data: team.logoData, name: team.name, size: 60)
                VStack(alignment: .leading, spacing: 5) {
                    Text(team.name).font(.title3.bold()).foregroundStyle(.primary)
                    Text("\(team.memberIDs.count) joueurs").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.secondary)
            }
            HStack(spacing: 18) {
                LabelValue(label: "Victoires", value: "\(summary.wins)")
                LabelValue(label: "Défaites", value: "\(summary.losses)")
                LabelValue(label: "Nuls", value: "\(summary.ties)")
            }.foregroundStyle(.primary)
            Divider()
            if let next {
                VStack(alignment: .leading, spacing: 5) {
                    Text("PROCHAIN MATCH").font(.caption2.bold()).foregroundStyle(.secondary)
                    Label(next.date.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                        .font(.caption.bold()).foregroundStyle(SportTheme.accent)
                }
            } else {
                Label("Aucun match à venir", systemImage: "calendar").font(.caption).foregroundStyle(.secondary)
            }
        }.sportPanel()
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
            MatchPlanningSheet(club: club, initialTeamID: team.id)
        }
    }
}

@MainActor
struct MatchRow: View {
    let game: MatchGame
    @Query private var teams: [Team]
    private var home: Team? { teams.first { $0.id == game.teamID && $0.clubID == game.clubID } }
    private var away: Team? { teams.first { $0.id == game.opponentTeamID && $0.clubID == game.clubID } }
    private var homeName: String { home?.name ?? "Bleus" }
    private var awayName: String { away?.name ?? (game.opponentName.isEmpty ? "Rouges" : game.opponentName) }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Label(game.isFinished ? "TERMINÉ" : "À VENIR", systemImage: game.isFinished ? "checkmark.circle.fill" : "calendar")
                    .font(.caption2.bold()).foregroundStyle(game.isFinished ? SportTheme.performanceInk : SportTheme.accent)
                Spacer()
                Text(game.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { homeIdentity; score; awayIdentity }
                VStack(spacing: 12) {
                    HStack(alignment: .top) { homeIdentity; awayIdentity }
                    score
                }
            }
            HStack(alignment: .top, spacing: 12) {
                Label(game.date.formatted(date: .omitted, time: .shortened), systemImage: "clock")
                Label(game.venue.isEmpty ? "Lieu à confirmer" : game.venue, systemImage: "mappin.and.ellipse")
            }.font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
    private var homeIdentity: some View {
        VStack(spacing: 8) {
            SportAvatar(data: home?.logoData, name: homeName, size: 48)
            Text(homeName).font(.subheadline.bold()).foregroundStyle(.primary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity)
    }
    private var awayIdentity: some View {
        VStack(spacing: 8) {
            SportAvatar(data: away?.logoData, name: awayName, size: 48)
            Text(awayName).font(.subheadline.bold()).foregroundStyle(.primary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity)
    }
    private var score: some View {
        VStack(spacing: 4) {
            Text(game.isFinished ? "\(game.blueScore) – \(game.redScore)" : "VS")
                .font(.system(.title, design: .rounded).weight(.heavy)).monospacedDigit().foregroundStyle(.primary).fixedSize(horizontal: true, vertical: false)
            Text(game.isFinished ? "SCORE FINAL" : "\(game.participants.count) PRÉSENTS")
                .font(.caption2.bold()).foregroundStyle(.secondary)
        }
    }
}
