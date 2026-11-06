import SwiftUI
import SwiftData
import UIKit

struct MatchesView: View {
    let club: Club
    @Query(sort: \MatchGame.date, order: .reverse) private var allGames: [MatchGame]
    @Query(sort: \Season.createdAt, order: .reverse) private var allSeasons: [Season]
    @State private var creating = false
    private var seasons: [Season] { allSeasons.filter { $0.clubID == club.id } }
    var body: some View {
        NavigationStack {
            List {
                ForEach(allGames.filter { $0.clubID == club.id }) { game in
                    NavigationLink { MatchDetailsView(game: game) } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(game.date.formatted(date: .abbreviated, time: .shortened)).font(.headline)
                                Spacer()
                                Text(game.isFinished ? "Terminé" : "À venir")
                                    .font(.caption).foregroundStyle(game.isFinished ? Color.secondary : Color.mint)
                            }
                            Text(game.venue.isEmpty ? "Lieu à confirmer" : game.venue)
                                .font(.subheadline).foregroundStyle(.secondary)
                            HStack {
                                Text("Bleus \(game.blueScore) — \(game.redScore) Rouges")
                                Spacer()
                                Text("\(game.participants.count) joueurs")
                            }.font(.caption)
                        }.padding(.vertical, 4)
                    }
                }
            }
            .overlay {
                if allGames.filter({ $0.clubID == club.id }).isEmpty {
                    EmptyHint(title: "Aucun match", subtitle: "Planifie ton premier match.")
                }
            }
            .navigationTitle("Matchs")
            .toolbar { Button { creating = true } label: { Image(systemName: "plus") } }
            .sheet(isPresented: $creating) {
                if let season = seasons.first { NewMatchView(club: club, season: season) }
                else { Text("Ajoute une saison dans l’onglet Stats.") }
            }
        }
    }
}

struct NewMatchView: View {
    let club: Club
    let season: Season
    @Environment(\.modelContext) private var context
    @State private var saveError: String?
    private func saveChanges() -> Bool {
        do { try context.save(); return true }
        catch { context.rollback(); saveError = "Sauvegarde impossible : \(error.localizedDescription)"; return false }
    }
    @Environment(\.dismiss) private var dismiss
    @Query private var allPlayers: [Player]
    @State private var date = Date()
    @State private var venue = ""
    @State private var costText = "0"
    @State private var attending = Set<UUID>()
    private var players: [Player] { allPlayers.filter { $0.clubID == club.id } }
    var body: some View {
        NavigationStack {
            Form {
                Section("Partie") {
                    DatePicker("Date et heure", selection: $date)
                    TextField("Terrain / lieu", text: $venue)
                    TextField("Coût total (CAD)", text: $costText).keyboardType(.decimalPad)
                    if InputValidation.cost(costText) == nil {
                        Text("Saisissez un montant entre 0 et 1 000 000 $, avec une virgule ou un point décimal.").font(.caption).foregroundStyle(.red)
                    }
                }
                Section("Joueurs présents (\(attending.count))") {
                    if players.isEmpty { Text("Ajoutez au moins deux joueurs dans Effectif.") }
                    else if attending.count < 2 { Text("Sélectionnez au moins deux participants.").font(.caption) }
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
                    Text("Les joueurs seront répartis automatiquement selon les overalls. Tu pourras ajuster les équipes ensuite.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Nouveau match")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") {
                        guard let amount = InputValidation.cost(costText) else { return }
                        let match = MatchGame(clubID: club.id, seasonID: season.id, date: date,
                                              venue: venue, totalCost: max(0, amount))
                        let teams = TeamsBalancer.split(players.filter { attending.contains($0.id) })
                        match.blueIDs = teams.blue
                        match.redIDs = teams.red
                        context.insert(match); if saveChanges() { dismiss() }
                    }.disabled(attending.count < 2 || InputValidation.cost(costText) == nil)
                }
            }
        }
        .alert("Erreur de sauvegarde", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: { Text(saveError ?? "") }

    }
}

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
    private var players: [Player] { allPlayers.filter { $0.clubID == game.clubID } }
    private var matchEntries: [StatEntry] { allEntries.filter { $0.matchID == game.id }.sorted { $0.createdAt > $1.createdAt } }
    private func playerName(_ id: UUID) -> String { players.first(where: { $0.id == id })?.name ?? "Joueur supprimé" }
    private var participants: [Player] { players.filter { game.participants.contains($0.id) }.sorted { $0.name < $1.name } }

    var body: some View {
        Form {
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
                Button("Rééquilibrer les équipes") {
                    let t = TeamsBalancer.split(participants)
                    game.blueIDs = t.blue; game.redIDs = t.red
                }.disabled(game.isFinished || !matchEntries.isEmpty)
                Text("Les équipes sont verrouillées après la première stat ou la fin du match. Supprimez les stats et rouvrez le match pour les corriger.").font(.caption)
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
                        Text(StatKind(rawValue: entry.kind)?.title ?? entry.kind)
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
                    Toggle("Ajouter les points au score officiel", isOn: $addToScore)
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
                        guard let primaryID else { return }
                        let entries = FootballEvents.make(game: game, kind: kind, playerID: primaryID, receiverID: receiverID)
                        guard !entries.isEmpty else { return }
                        for entry in entries { context.insert(entry) }
                        if addToScore {
                            FootballEvents.applyScore(kind: kind, playerID: primaryID, game: game)
                        }
                        if saveChanges() { dismiss() }
                    }.disabled(primaryID == nil || (kind == .passTD && !validReceiver))
                }
            }
        }
        .alert("Erreur de sauvegarde", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: { Text(saveError ?? "") }

    }
}
