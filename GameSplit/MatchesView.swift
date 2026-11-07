import SwiftUI
import SwiftData
import UIKit

@MainActor
struct MatchesView: View {
    let club: Club
    @Query(sort: \MatchGame.date, order: .reverse) private var allGames: [MatchGame]
    @Query(sort: \Season.createdAt, order: .reverse) private var allSeasons: [Season]
    @State private var creating = false
    @State private var statusFilter = "Tous"
    private var seasons: [Season] { allSeasons.filter { $0.clubID == club.id } }
    var body: some View {
        NavigationStack {
            List {
                Picker("Afficher", selection: $statusFilter) {
                    Text("Tous").tag("Tous"); Text("À venir").tag("À venir"); Text("Terminés").tag("Terminés")
                }.pickerStyle(.segmented)
                ForEach(allGames.filter { $0.clubID == club.id && (statusFilter == "Tous" || (statusFilter == "Terminés") == $0.isFinished) }) { game in
                    NavigationLink { MatchDetailsView(game: game) } label: { MatchRow(game: game) }
                }
            }
            .overlay {
                if allGames.filter({ $0.clubID == club.id }).isEmpty {
                    EmptyHint(title: "Aucun match", subtitle: "Planifie ton premier match.")
                }
            }
            .navigationTitle("Matchs")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { NavigationLink("Importer CSV") { CalendarImportView(club: club) } }
                ToolbarItem(placement: .topBarTrailing) { Button("Créer", systemImage: "plus") { creating = true } }
            }
            .sheet(isPresented: $creating) {
                if let season = seasons.first { NewMatchView(club: club, season: season) }
                else { NewSeasonView(clubID: club.id) }
            }
        }
    }
}

@MainActor
struct NewMatchView: View {
    let club: Club
    let season: Season
    var initialTeamID: UUID? = nil
    @Environment(\.modelContext) private var context
    @State private var saveError: String?
    private func saveChanges() -> Bool {
        do { try context.save(); return true }
        catch { context.rollback(); saveError = "Sauvegarde impossible : \(error.localizedDescription)"; return false }
    }
    @Environment(\.dismiss) private var dismiss
    @Query private var allPlayers: [Player]
    @Query(sort: \Team.name) private var allTeams: [Team]
    @State private var selectedTeamID: UUID?
    @State private var opponentTeamID: UUID?
    @State private var opponentName = ""
    @State private var initialized = false
    private var teams: [Team] { allTeams.filter { $0.clubID == club.id } }
    @State private var date = Date()
    @State private var venue = ""
    @State private var costText = "0"
    @State private var attending = Set<UUID>()
    private var players: [Player] { allPlayers.filter { $0.clubID == club.id } }
    var body: some View {
        NavigationStack {
            Form {
                Section("Équipes") {
                    Picker("Votre équipe (Bleus)", selection: $selectedTeamID) {
                        Text("Match entre amis / équipes équilibrées").tag(UUID?.none)
                        ForEach(teams) { Text($0.name).tag(Optional($0.id)) }
                    }
                    if selectedTeamID != nil {
                        Picker("Adversaire (Rouges)", selection: $opponentTeamID) {
                            Text("Saisie manuelle").tag(UUID?.none)
                            ForEach(teams.filter { $0.id != selectedTeamID }) { Text($0.name).tag(Optional($0.id)) }
                        }
                        if opponentTeamID == nil { TextField("Nom de l’adversaire", text: $opponentName) }
                        Text("Les présents de votre équipe seront Bleus, ceux de l’adversaire Rouges. Un joueur commun reste du côté de votre équipe.").font(.caption)
                    }
                }
                Section("Partie") {
                    DatePicker("Date et heure", selection: $date)
                    TextField("Terrain / lieu", text: $venue)
                    TextField("Coût total (CAD)", text: $costText).keyboardType(.decimalPad)
                    if InputValidation.cost(costText) == nil {
                        Text("Saisissez un montant entre 0 et 1 000 000 $, avec une virgule ou un point décimal.").font(.caption).foregroundStyle(.red)
                    }
                }
                Section("Joueurs présents (\(attending.count))") {
                    if players.isEmpty { Text("Ajoutez les joueurs depuis Équipes → Tous les joueurs.") }
                    else if selectedTeamID == nil && attending.count < 2 { Text("Sélectionnez au moins deux participants.").font(.caption) }
                    ForEach(players) { player in
                        Toggle(player.name, isOn: Binding(
                            get: { attending.contains(player.id) },
                            set: { on in
                                if on { attending.insert(player.id) } else { attending.remove(player.id) }
                            }
                        ))
                    }
                }
                Section {
                    Text(selectedTeamID == nil ? "Répartition automatique selon les overalls, ajustable ensuite." : "Les effectifs des équipes sont préremplis. Ajustez les présents et les côtés avant de saisir les statistiques.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Nouveau match")
            .onAppear {
                guard !initialized else { return }; initialized = true
                selectedTeamID = initialTeamID
                if let team = teams.first(where: { $0.id == initialTeamID }) { attending = team.memberIDs }
            }
            .onChange(of: selectedTeamID) { _, id in
                if opponentTeamID == id { opponentTeamID = nil }
                if let team = teams.first(where: { $0.id == id }) {
                    attending = team.memberIDs.union(teams.first(where: { $0.id == opponentTeamID })?.memberIDs ?? [])
                }
            }
            .onChange(of: opponentTeamID) { _, id in
                if let team = teams.first(where: { $0.id == selectedTeamID }) {
                    attending = team.memberIDs.union(teams.first(where: { $0.id == id })?.memberIDs ?? [])
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") {
                        guard let amount = InputValidation.cost(costText) else { return }
                        let match = MatchGame(clubID: club.id, seasonID: season.id, date: date,
                                              venue: venue, totalCost: max(0, amount))
                        match.teamID = selectedTeamID; match.opponentTeamID = selectedTeamID == nil ? nil : opponentTeamID
                        match.opponentName = selectedTeamID == nil ? "" : opponentName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let selected = players.filter { attending.contains($0.id) }
                        if let home = teams.first(where: { $0.id == selectedTeamID }) {
                            let away = teams.first(where: { $0.id == opponentTeamID })
                            match.blueIDs = Set(selected.filter { home.memberIDs.contains($0.id) || !(away?.memberIDs.contains($0.id) ?? false) }.map(\.id))
                            match.redIDs = Set(selected.map(\.id)).subtracting(match.blueIDs)
                        } else {
                            let split = TeamsBalancer.split(selected)
                            match.blueIDs = split.blue; match.redIDs = split.red
                        }
                        context.insert(match); if saveChanges() { dismiss() }
                    }.disabled((selectedTeamID == nil && attending.count < 2) || InputValidation.cost(costText) == nil || (selectedTeamID != nil && opponentTeamID == nil && opponentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                }
            }
        }
        .alert("Erreur de sauvegarde", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: { Text(saveError ?? "") }

    }
}

@MainActor
struct MatchDetailsView: View {
    @Bindable var game: MatchGame
    @Environment(\.modelContext) private var context
    @State private var saveError: String?
    private func saveChanges() -> Bool {
        do { try context.save(); return true }
        catch { context.rollback(); saveError = "Sauvegarde impossible : \(error.localizedDescription)"; return false }
    }
    @Query private var allPlayers: [Player]
    @Query private var allEntries: [StatEntry]
    @State private var showingStat = false
    @State private var editingInfo = false
    @State private var editingRoster = false
    private var players: [Player] { allPlayers.filter { $0.clubID == game.clubID } }
    private var matchEntries: [StatEntry] { allEntries.filter { $0.matchID == game.id }.sorted { $0.createdAt > $1.createdAt } }
    private func playerName(_ id: UUID) -> String { players.first(where: { $0.id == id })?.name ?? "Joueur supprimé" }
    private var participants: [Player] { players.filter { game.participants.contains($0.id) }.sorted { $0.name < $1.name } }

    var body: some View {
        Form {
            Section("Match") {
                MatchRow(game: game)
                Button("Modifier date, lieu et adversaire") { editingInfo = true }
            }
            Section("Résultat") {
                HStack {
                    VStack {
                        Text("BLEUS").font(.caption.bold()).foregroundStyle(.blue)
                        Text("\(game.blueScore)").font(.largeTitle.bold()).monospacedDigit()
                    }.frame(maxWidth: .infinity)
                    Text("–").font(.title).foregroundStyle(.secondary)
                    VStack {
                        Text("ROUGES").font(.caption.bold()).foregroundStyle(.red)
                        Text("\(game.redScore)").font(.largeTitle.bold()).monospacedDigit()
                    }.frame(maxWidth: .infinity)
                }.padding(.vertical, 8)
                Stepper("Points bleus : \(game.blueScore)", value: $game.blueScore, in: 0...500)
                Stepper("Points rouges : \(game.redScore)", value: $game.redScore, in: 0...500)
                Toggle("Match terminé", isOn: $game.isFinished)
                Text("Score officiel modifiable. À l’ajout d’un événement, vous choisissez d’ajouter ses points. Supprimer une stat ne change pas le score : corrigez-le ici si nécessaire.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Règles locales — aide au décompte") {
                Stepper("Points par TD : \(game.touchdownPoints)", value: $game.touchdownPoints, in: 1...12)
                Stepper("Points par conversion : \(game.conversionPoints)", value: $game.conversionPoints, in: 1...3)
                Text("Ces valeurs servent de référence. Saisissez le résultat officiel dans la section Résultat.").font(.caption)
            }
            Section("Équipes • \(game.participants.count) joueurs") {
                Button("Modifier les présents") { editingRoster = true }.disabled(game.isFinished || !matchEntries.isEmpty)
                Button("Rééquilibrer les équipes") {
                    let t = TeamsBalancer.split(participants)
                    game.blueIDs = t.blue; game.redIDs = t.red
                }.disabled(game.isFinished || !matchEntries.isEmpty)
                Text("Votre équipe correspond aux Bleus, l’adversaire aux Rouges. Les équipes sont verrouillées après la première stat ou la fin du match. Supprimez les stats et rouvrez le match pour les corriger.").font(.caption)
                ForEach(participants) { player in
                    HStack {
                        Text(player.name)
                        Spacer()
                        Text("\(player.overall) OVR").font(.caption).foregroundStyle(.secondary)
                        Picker("Équipe", selection: Binding<String>(
                            get: { game.blueIDs.contains(player.id) ? "blue" : "red" },
                            set: { selected in
                                var b = game.blueIDs; var r = game.redIDs
                                b.remove(player.id); r.remove(player.id)
                                if selected == "blue" { b.insert(player.id) } else { r.insert(player.id) }
                                game.blueIDs = b; game.redIDs = r
                            }
                        )) {
                            Text("Bleu").tag("blue")
                            Text("Rouge").tag("red")
                        }.pickerStyle(.menu).disabled(game.isFinished || !matchEntries.isEmpty)
                    }
                }
            }
            Section("Statistiques") {
                Button { showingStat = true } label: { Label("Ajouter un événement", systemImage: "plus.circle.fill") }.disabled(participants.isEmpty)
                Text("Pour corriger une saisie, supprimez l’événement puis ajoutez la bonne version. Une passe et sa réception sont supprimées ensemble.").font(.caption)
                ForEach(matchEntries) { entry in
                    HStack {
                        Text(playerName(entry.playerID))
                        Spacer()
                        Text("\(entry.value) × \(StatKind(rawValue: entry.kind)?.title ?? entry.kind)")
                            .foregroundStyle(.secondary).font(.caption)
                    }
                }
                .onDelete { indexSet in
                    // Event deletion does not change manually editable scores.
                    let selected = indexSet.map { matchEntries[$0] }
                    let ids = Set(selected.flatMap { FootballEvents.related(to: $0, in: matchEntries) }.map(\.id))
                    for entry in matchEntries where ids.contains(entry.id) { context.delete(entry) }
                    _ = saveChanges()
                }
            }
            Section("Résumé") {
                ShareLink(item: "GameSplit — \(game.date.formatted(date: .abbreviated, time: .shortened))\n\(game.venue)\nBleus \(game.blueScore) — \(game.redScore) Rouges\n\(game.isFinished ? "Terminé" : "En cours")") {
                    Label("Partager le résultat", systemImage: "square.and.arrow.up")
                }
            }
            Section("Partage des coûts") {
                LabeledContent("Coût total", value: game.totalCost, format: .currency(code: "CAD"))
                LabeledContent("Coût par joueur", value: game.costPerPlayer, format: .currency(code: "CAD"))
                LabeledContent("Reçu", value: Double(game.paidIDs.intersection(game.participants).count) * game.costPerPlayer,
                               format: .currency(code: "CAD"))
                ForEach(participants) { player in
                    Toggle(player.name, isOn: Binding(
                        get: { game.paidIDs.contains(player.id) },
                        set: { paid in
                            var ids = game.paidIDs
                            if paid { ids.insert(player.id) } else { ids.remove(player.id) }
                            game.paidIDs = ids
                        }
                    ))
                }
                LabeledContent("Reste à recevoir", value: game.outstanding, format: .currency(code: "CAD"))
                Button("Copier le rappel") { UIPasteboard.general.string = paymentMessage }
                ShareLink(item: paymentMessage) { Label("Partager le rappel de paiement", systemImage: "square.and.arrow.up") }
            }
        }
        .navigationTitle(game.date.formatted(date: .abbreviated, time: .omitted))
        .onChange(of: game.blueScore) { _, _ in _ = saveChanges() }
        .onChange(of: game.redScore) { _, _ in _ = saveChanges() }
        .onChange(of: game.isFinished) { _, _ in _ = saveChanges() }
        .onChange(of: game.bluePlayerIDs) { _, _ in _ = saveChanges() }
        .onChange(of: game.redPlayerIDs) { _, _ in _ = saveChanges() }
        .onChange(of: game.paidPlayerIDs) { _, _ in _ = saveChanges() }
        .onChange(of: game.touchdownPoints) { _, _ in _ = saveChanges() }
        .onChange(of: game.conversionPoints) { _, _ in _ = saveChanges() }
        .sheet(isPresented: $editingRoster) { MatchRosterEditor(game: game) }
        .sheet(isPresented: $editingInfo) { MatchInfoEditor(game: game) }
        .sheet(isPresented: $showingStat) { AddStatView(game: game, participants: participants) }
        .alert("Erreur de sauvegarde", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: { Text(saveError ?? "") }

    }
    private var paymentMessage: String {
        let unpaid = participants.filter { !game.paidIDs.contains($0.id) }.map(\.name).joined(separator: ", ")
        return "🏈 GameSplit — \(game.date.formatted(date: .abbreviated, time: .shortened))\n" +
               "Part : \(game.costPerPlayer.formatted(.currency(code: "CAD"))) / joueur\n" +
               "Paiements en attente : \(unpaid.isEmpty ? "aucun" : unpaid)"
    }
}

@MainActor
struct AddStatView: View {
    @Bindable var game: MatchGame
    let participants: [Player]
    @Environment(\.modelContext) private var context
    @State private var saveError: String?
    private func saveChanges() -> Bool {
        do { try context.save(); return true }
        catch { context.rollback(); saveError = "Sauvegarde impossible : \(error.localizedDescription)"; return false }
    }
    @Environment(\.dismiss) private var dismiss
    @State private var kind: StatKind = .passTD
    @State private var primaryID: UUID?
    @State private var receiverID: UUID?
    @State private var addToScore = true
    @State private var quantityText = "1"
    private var quantity: Int? { guard let value = Int(quantityText), (1...10_000).contains(value) else { return nil }; return value }
    private var validReceiver: Bool {
        guard let primaryID, let receiverID else { return false }
        return primaryID != receiverID &&
            ((game.blueIDs.contains(primaryID) && game.blueIDs.contains(receiverID)) ||
             (game.redIDs.contains(primaryID) && game.redIDs.contains(receiverID)))
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Statistique", selection: $kind) {
                        ForEach(StatKind.allCases) { Text($0.title).tag($0) }
                    }
                }
                Section("Valeur") {
                    TextField("Nombre / verges", text: $quantityText).keyboardType(.numberPad)
                    Text("Réceptions : les TD sur réception sont déjà comptés automatiquement. Saisissez ici les réceptions hors TD. Les verges se saisissent séparément.").font(.caption)
                    if quantity == nil { Text("Saisissez un entier entre 1 et 10 000.").foregroundStyle(.red) }
                }
                Section("Joueur") {
                    Picker(kind == .passTD ? "Quarterback" : "Joueur", selection: $primaryID) {
                        Text("Sélectionner").tag(UUID?.none)
                        ForEach(participants) { player in Text(player.name).tag(Optional(player.id)) }
                    }
                    if kind == .passTD {
                        Picker("Receveur", selection: $receiverID) {
                            Text("Sélectionner").tag(UUID?.none)
                            ForEach(participants) { player in Text(player.name).tag(Optional(player.id)) }
                        }
                        if primaryID != nil && receiverID != nil && !validReceiver {
                            Text("QB et receveur doivent être deux coéquipiers distincts.")
                                .font(.caption).foregroundStyle(.red)
                        }
                    }
                }
                Section {
                    Toggle("Ajouter les points au score officiel", isOn: $addToScore).disabled(FootballEvents.points(kind: kind, game: game) == 0)
                    Text("Référence : TD = \(game.touchdownPoints) points, conversion = \(game.conversionPoints). Une passe TD compte une seule fois pour l’équipe. Pour compléter des statistiques après avoir saisi le résultat, désactivez l’ajout au score.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Ajouter une stat")
            .onAppear { addToScore = !game.isFinished }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        guard let primaryID, let quantity else { return }
                        let entries = FootballEvents.make(game: game, kind: kind, playerID: primaryID, receiverID: receiverID, value: quantity)
                        guard !entries.isEmpty else { return }
                        for entry in entries { context.insert(entry) }
                        if addToScore {
                            FootballEvents.applyScore(kind: kind, playerID: primaryID, game: game, value: quantity)
                        }
                        if saveChanges() { dismiss() }
                    }.disabled(primaryID == nil || quantity == nil || (kind == .passTD && !validReceiver))
                }
            }
        }
        .alert("Erreur de sauvegarde", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: { Text(saveError ?? "") }

    }
}


@MainActor
struct MatchInfoEditor: View {
    let game: MatchGame
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var venue = ""
    @State private var opponent = ""
    @State private var initialized = false
    @State private var errorMessage: String?
    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date et heure", selection: $date)
                TextField("Lieu", text: $venue)
                if game.opponentTeamID == nil { TextField("Adversaire", text: $opponent) }
                Text("Modifier ces informations conserve les participants, statistiques, scores et paiements existants.").font(.caption)
            }
            .navigationTitle("Modifier le match")
            .onAppear {
                guard !initialized else { return }; initialized = true
                date = game.date; venue = game.venue; opponent = game.opponentName
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        game.date = date; game.venue = venue.trimmingCharacters(in: .whitespacesAndNewlines)
                        game.opponentName = opponent.trimmingCharacters(in: .whitespacesAndNewlines)
                        do { try context.save(); dismiss() } catch { context.rollback(); errorMessage = error.localizedDescription }
                    }
                }
            }
        }
        .alert("Sauvegarde", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }
}


@MainActor
struct MatchRosterEditor: View {
    let game: MatchGame
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Player.name) private var allPlayers: [Player]
    @Query private var entries: [StatEntry]
    @State private var blue = Set<UUID>()
    @State private var red = Set<UUID>()
    @State private var initialized = false
    @State private var errorMessage: String?
    var body: some View {
        NavigationStack {
            Form {
                Text("Choisissez les présents et leur côté. Pour préserver les paiements, un joueur déjà marqué payé ne peut pas être retiré.").font(.caption)
                ForEach(allPlayers.filter { $0.clubID == game.clubID }) { player in
                    Picker(player.name, selection: Binding<String>(get: { blue.contains(player.id) ? "blue" : (red.contains(player.id) ? "red" : "absent") }, set: { side in
                        blue.remove(player.id); red.remove(player.id)
                        if side == "blue" { blue.insert(player.id) }; if side == "red" { red.insert(player.id) }
                    })) {
                        if !game.paidIDs.contains(player.id) { Text("Absent").tag("absent") }
                        Text("Bleus").tag("blue"); Text("Rouges").tag("red")
                    }
                }
            }
            .navigationTitle("Présents")
            .onAppear { if !initialized { blue = game.blueIDs; red = game.redIDs; initialized = true } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        guard !game.isFinished, !entries.contains(where: { $0.matchID == game.id }),
                              game.paidIDs.isSubset(of: blue.union(red)) else { errorMessage = "Le match est verrouillé ou des paiements seraient perdus."; return }
                        game.blueIDs = blue; game.redIDs = red
                        do { try context.save(); dismiss() } catch { context.rollback(); errorMessage = error.localizedDescription }
                    }
                }
            }
        }
        .alert("Présents", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }
}
