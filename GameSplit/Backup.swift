import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct LocalBackup: Codable {
    var version = 1
    var clubs: [ClubRecord]
    var seasons: [SeasonRecord]
    var players: [PlayerRecord]
    var matchgames: [MatchGameRecord]
    var statentrys: [StatEntryRecord]
    @MainActor init(context: ModelContext) throws {
        clubs = try context.fetch(FetchDescriptor<Club>()).map(ClubRecord.init)
        seasons = try context.fetch(FetchDescriptor<Season>()).map(SeasonRecord.init)
        players = try context.fetch(FetchDescriptor<Player>()).map(PlayerRecord.init)
        matchgames = try context.fetch(FetchDescriptor<MatchGame>()).map(MatchGameRecord.init)
        statentrys = try context.fetch(FetchDescriptor<StatEntry>()).map(StatEntryRecord.init)
    }
    /// Restore only into an empty store; never overwrite existing local data.
    @MainActor func restore(context: ModelContext) throws {
        guard version == 1 else { throw BackupError.invalid }
        guard try context.fetchCount(FetchDescriptor<Club>()) == 0 else { throw BackupError.notEmpty }
        guard try context.fetchCount(FetchDescriptor<Season>()) == 0 else { throw BackupError.notEmpty }
        guard try context.fetchCount(FetchDescriptor<Player>()) == 0 else { throw BackupError.notEmpty }
        guard try context.fetchCount(FetchDescriptor<MatchGame>()) == 0 else { throw BackupError.notEmpty }
        guard try context.fetchCount(FetchDescriptor<StatEntry>()) == 0 else { throw BackupError.notEmpty }
        let clubs = Set(self.clubs.map(\.id)), seasons = Set(self.seasons.map(\.id))
        let players = Set(self.players.map(\.id)), matches = Set(matchgames.map(\.id))
        guard clubs.count <= 1, clubs.count == self.clubs.count, seasons.count == self.seasons.count,
              players.count == self.players.count, matches.count == matchgames.count,
              Set(statentrys.map(\.id)).count == statentrys.count else { throw BackupError.invalid }
        for c in self.clubs where c.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || c.sport != "football" { throw BackupError.invalid }
        for s in self.seasons where !clubs.contains(s.clubID) || s.name.isEmpty { throw BackupError.invalid }
        for p in self.players where !clubs.contains(p.clubID) || p.name.isEmpty || !(1...99).contains(p.overall) || !(0...99).contains(p.number) || Position(rawValue: p.position) == nil { throw BackupError.invalid }
        for g in matchgames {
            for text in [g.bluePlayerIDs, g.redPlayerIDs, g.paidPlayerIDs] {
                guard text.isEmpty || text.split(separator: ",", omittingEmptySubsequences: false).allSatisfy({ UUID(uuidString: String($0)) != nil }) else { throw BackupError.invalid }
            }
            let blue = IDList.decode(g.bluePlayerIDs), red = IDList.decode(g.redPlayerIDs)
            guard clubs.contains(g.clubID), seasons.contains(g.seasonID),
                  self.seasons.contains(where: { $0.id == g.seasonID && $0.clubID == g.clubID }),
                  blue.isDisjoint(with: red), blue.union(red).isSubset(of: players),
                  self.players.filter({ blue.union(red).contains($0.id) }).allSatisfy({ $0.clubID == g.clubID }),
                  IDList.decode(g.paidPlayerIDs).isSubset(of: blue.union(red)),
                  g.totalCost.isFinite, g.totalCost >= 0, g.totalCost <= 1_000_000,
                  g.blueScore >= 0, g.redScore >= 0,
                  (1...12).contains(g.touchdownPoints), (1...3).contains(g.conversionPoints) else { throw BackupError.invalid }
        }
        for e in statentrys {
            guard matches.contains(e.matchID), players.contains(e.playerID), StatKind(rawValue: e.kind) != nil,
                  let game = matchgames.first(where: { $0.id == e.matchID }),
                  IDList.decode(game.bluePlayerIDs).union(IDList.decode(game.redPlayerIDs)).contains(e.playerID) else { throw BackupError.invalid }
        }
        let linked = Dictionary(grouping: statentrys.filter { $0.eventID != nil }, by: { $0.eventID! })
        for pair in linked.values {
            guard pair.count == 2, Set(pair.map(\.kind)) == Set([StatKind.passTD.rawValue, StatKind.receivingTD.rawValue]),
                  pair[0].matchID == pair[1].matchID, pair[0].playerID != pair[1].playerID,
                  let game = matchgames.first(where: { $0.id == pair[0].matchID }),
                  IDList.decode(game.bluePlayerIDs).contains(pair[0].playerID) == IDList.decode(game.bluePlayerIDs).contains(pair[1].playerID) else { throw BackupError.invalid }
        }
        do {
            for record in self.clubs { context.insert(record.model()) }
            for record in self.seasons { context.insert(record.model()) }
            for record in self.players { context.insert(record.model()) }
            for record in matchgames { context.insert(record.model()) }
            for record in statentrys { context.insert(record.model()) }
            try context.save()
        } catch { context.rollback(); throw error }
    }
}

enum BackupError: LocalizedError {
    case invalid, notEmpty
    var errorDescription: String? {
        switch self {
        case .invalid: return "Sauvegarde invalide ou version non prise en charge."
        case .notEmpty: return "La restauration exige une installation vide pour protéger vos données existantes."
        }
    }
}

struct ClubRecord: Codable {
    var id: UUID
    var name: String
    var sport: String
    var createdAt: Date
    init(_ value: Club) {
        id = value.id
        name = value.name
        sport = value.sport
        createdAt = value.createdAt
    }
    func model() -> Club {
        let value = Club(name: name, sport: sport)
        value.id = id
        value.name = name
        value.sport = sport
        value.createdAt = createdAt
        return value
    }
}

struct SeasonRecord: Codable {
    var id: UUID
    var clubID: UUID
    var name: String
    var createdAt: Date
    init(_ value: Season) {
        id = value.id
        clubID = value.clubID
        name = value.name
        createdAt = value.createdAt
    }
    func model() -> Season {
        let value = Season(clubID: clubID, name: name)
        value.id = id
        value.clubID = clubID
        value.name = name
        value.createdAt = createdAt
        return value
    }
}

struct PlayerRecord: Codable {
    var id: UUID
    var clubID: UUID
    var name: String
    var position: String
    var number: Int
    var overall: Int
    var createdAt: Date
    init(_ value: Player) {
        id = value.id
        clubID = value.clubID
        name = value.name
        position = value.position
        number = value.number
        overall = value.overall
        createdAt = value.createdAt
    }
    func model() -> Player {
        let value = Player(clubID: clubID, name: name, position: position, number: number, overall: overall)
        value.id = id
        value.clubID = clubID
        value.name = name
        value.position = position
        value.number = number
        value.overall = overall
        value.createdAt = createdAt
        return value
    }
}

struct MatchGameRecord: Codable {
    var id: UUID
    var clubID: UUID
    var seasonID: UUID
    var date: Date
    var venue: String
    var bluePlayerIDs: String
    var redPlayerIDs: String
    var paidPlayerIDs: String
    var totalCost: Double
    var blueScore: Int
    var redScore: Int
    var isFinished: Bool
    var touchdownPoints: Int
    var conversionPoints: Int
    init(_ value: MatchGame) {
        id = value.id
        clubID = value.clubID
        seasonID = value.seasonID
        date = value.date
        venue = value.venue
        bluePlayerIDs = value.bluePlayerIDs
        redPlayerIDs = value.redPlayerIDs
        paidPlayerIDs = value.paidPlayerIDs
        totalCost = value.totalCost
        blueScore = value.blueScore
        redScore = value.redScore
        isFinished = value.isFinished
        touchdownPoints = value.touchdownPoints
        conversionPoints = value.conversionPoints
    }
    func model() -> MatchGame {
        let value = MatchGame(clubID: clubID, seasonID: seasonID, date: date, venue: venue, totalCost: totalCost)
        value.id = id
        value.clubID = clubID
        value.seasonID = seasonID
        value.date = date
        value.venue = venue
        value.bluePlayerIDs = bluePlayerIDs
        value.redPlayerIDs = redPlayerIDs
        value.paidPlayerIDs = paidPlayerIDs
        value.totalCost = totalCost
        value.blueScore = blueScore
        value.redScore = redScore
        value.isFinished = isFinished
        value.touchdownPoints = touchdownPoints
        value.conversionPoints = conversionPoints
        return value
    }
}

struct StatEntryRecord: Codable {
    var id: UUID
    var eventID: UUID?
    var matchID: UUID
    var playerID: UUID
    var kind: String
    var createdAt: Date
    init(_ value: StatEntry) {
        id = value.id
        eventID = value.eventID
        matchID = value.matchID
        playerID = value.playerID
        kind = value.kind
        createdAt = value.createdAt
    }
    func model() -> StatEntry {
        let value = StatEntry(matchID: matchID, playerID: playerID, kind: kind)
        value.id = id
        value.eventID = eventID
        value.matchID = matchID
        value.playerID = playerID
        value.kind = kind
        value.createdAt = createdAt
        return value
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw BackupError.invalid }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct BackupView: View {
    @Environment(\.modelContext) private var context
    @State private var document = BackupDocument()
    @State private var exporting = false
    @State private var importing = false
    @State private var message: String?
    var body: some View {
        Form {
            Section("Sauvegarde locale") {
                Text("Exportez régulièrement toutes vos données dans Fichiers. Aucune synchronisation automatique. Le fichier contient les noms, résultats et paiements : conservez-le dans un emplacement de confiance.")
                Button("Exporter la sauvegarde JSON") {
                    do {
                        document = BackupDocument(data: try JSONEncoder().encode(LocalBackup(context: context)))
                        exporting = true
                    } catch { message = error.localizedDescription }
                }
                Button("Restaurer une sauvegarde") { importing = true }
                Text("Import uniquement dans une installation vide. Aucun remplacement ni fusion des données existantes.").font(.caption)
            }
        }
        .navigationTitle("Sauvegarde")
        .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "GameSplit-sauvegarde") { result in
            if case .failure(let error) = result { message = error.localizedDescription }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 20_000_000 else { throw BackupError.invalid }
                let backup = try JSONDecoder().decode(LocalBackup.self, from: Data(contentsOf: url))
                try backup.restore(context: context)
                message = "Sauvegarde restaurée."
            } catch { message = error.localizedDescription }
        }
        .alert("Sauvegarde", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
    }
}
