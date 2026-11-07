import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct CalendarRow: Identifiable {
    let id = UUID()
    let date: Date
    let venue: String
    let opponent: String
    let teamName: String
    let cost: Double
}

enum CalendarCSVError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
}

enum CalendarCSV {
    static func parse(_ source: String) throws -> [CalendarRow] {
        guard source.utf8.count <= 2_000_000 else { throw CalendarCSVError.invalid("Fichier limité à 2 Mo.") }
        let text = source.replacingOccurrences(of: "\u{FEFF}", with: "").replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let separator: Character = (text.firstIndex(of: ";").map { index in index < (text.firstIndex(of: "\n") ?? text.endIndex) } ?? false) ? ";" : ","
        var rows: [[String]] = [], row: [String] = [], field = ""
        var quoted = false, closed = false
        let characters = Array(text)
        var index = 0
        while index < characters.count {
            let character = characters[index]
            if quoted {
                if character == "\"" {
                    if index + 1 < characters.count && characters[index + 1] == "\"" { field.append("\""); index += 1 }
                    else { quoted = false; closed = true }
                } else { field.append(character) }
            } else if character == separator {
                row.append(field); field = ""; closed = false
            } else if character == "\n" {
                row.append(field)
                if row.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) { rows.append(row) }
                row = []; field = ""; closed = false
            } else if character == "\"" {
                guard field.isEmpty && !closed else { throw CalendarCSVError.invalid("Guillemets CSV invalides.") }
                quoted = true
            } else {
                guard !closed || character.isWhitespace else { throw CalendarCSVError.invalid("Texte après fermeture des guillemets.") }
                if !closed { field.append(character) }
            }
            index += 1
        }
        guard !quoted else { throw CalendarCSVError.invalid("Guillemets CSV non fermés.") }
        row.append(field)
        if row.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) { rows.append(row) }
        guard let first = rows.first else { throw CalendarCSVError.invalid("Fichier vide.") }
        let headers = first.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        guard headers.contains("date"), Set(headers).count == headers.count else { throw CalendarCSVError.invalid("En-tête date obligatoire ; colonnes sans doublons.") }
        guard rows.count > 1, rows.count <= 2001 else { throw CalendarCSVError.invalid("Le fichier doit contenir entre 1 et 2 000 matchs.") }
        let iso = ISO8601DateFormatter()
        let local = DateFormatter(); local.locale = Locale(identifier: "en_US_POSIX")
        local.dateFormat = "yyyy-MM-dd HH:mm"; local.isLenient = false; local.timeZone = .current
        return try rows.dropFirst().enumerated().map { offset, values in
            guard values.count == headers.count else { throw CalendarCSVError.invalid("Ligne \(offset + 2) : nombre de colonnes incorrect.") }
            func value(_ name: String) -> String {
                guard let index = headers.firstIndex(of: name) else { return "" }
                return values[index].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let rawDate = value("date")
            guard let date = iso.date(from: rawDate) ?? (rawDate.count == 16 ? local.date(from: rawDate) : nil),
                  let cost = InputValidation.cost(value("cout").isEmpty ? "0" : value("cout")) else {
                throw CalendarCSVError.invalid("Ligne \(offset + 2) : date ou coût invalide.")
            }
            return CalendarRow(date: date, venue: value("lieu"), opponent: value("adversaire"), teamName: value("equipe"), cost: cost)
        }
    }
    static func key(seasonID: UUID, date: Date, venue: String, teamID: UUID?, opponent: String) -> String {
        func normalized(_ value: String) -> String {
            value.trimmingCharacters(in: .whitespacesAndNewlines).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fr_CA"))
        }
        // Length-prefixed components avoid collisions if user text contains separators.
        let parts = [seasonID.uuidString, String(Int(date.timeIntervalSince1970 / 60)), normalized(venue), teamID?.uuidString ?? "", normalized(opponent)]
        return parts.map { "\($0.utf8.count):\($0)" }.joined()
    }
}

@MainActor
struct CalendarImportView: View {
    let club: Club
    @Environment(\.modelContext) private var context
    @Query(sort: \Season.createdAt, order: .reverse) private var allSeasons: [Season]
    @Query private var allTeams: [Team]
    @Query private var allGames: [MatchGame]
    @State private var selectedSeason: UUID?
    @State private var importing = false
    @State private var rows: [CalendarRow] = []
    @State private var message: String?
    private var seasons: [Season] { allSeasons.filter { $0.clubID == club.id } }
    private var teams: [Team] { allTeams.filter { $0.clubID == club.id } }
    var body: some View {
        Form {
            Section("Calendrier CSV") {
                Text("Colonnes : date,lieu,adversaire,equipe,cout. Seule date est obligatoire. Format ISO 8601 avec fuseau, ou AAAA-MM-JJ HH:mm dans le fuseau du téléphone. Virgule ou point-virgule ; guillemets acceptés.").font(.subheadline)
                Text("Exemple : 2027-06-12T19:00:00-04:00,Parc Nord,Les Lynx,Éclairs,0").font(.caption).textSelection(.enabled)
                Picker("Saison", selection: $selectedSeason) {
                    Text("Choisir").tag(UUID?.none)
                    ForEach(seasons) { Text($0.name).tag(Optional($0.id)) }
                }
                Button("Choisir un fichier CSV") { importing = true }
                Text("Le nom d’équipe doit correspondre à une équipe existante. Les adversaires sont conservés en texte. Les présents et statistiques se renseignent après import. Les doublons de saison/date/lieu/équipe/adversaire sont ignorés.").font(.caption).foregroundStyle(.secondary)
            }
            if !rows.isEmpty {
                Section("Aperçu • \(rows.count) matchs") {
                    ForEach(Array(rows.prefix(20))) { row in
                        VStack(alignment: .leading) {
                            Text(row.date.formatted(date: .abbreviated, time: .shortened)).bold()
                            Text("\(row.teamName) — \(row.opponent) • \(row.venue)").font(.caption)
                        }
                    }
                    if rows.count > 20 { Text("… et \(rows.count - 20) autres matchs") }
                    Button("Confirmer l’importation") { importRows() }.disabled(selectedSeason == nil)
                }
            }
        }
        .navigationTitle("Importer un calendrier")
        .onAppear { if selectedSeason == nil { selectedSeason = seasons.first?.id } }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            do {
                let url = try result.get(); let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 2_000_000 else { throw CalendarCSVError.invalid("Fichier limité à 2 Mo.") }
                let parsed = try CalendarCSV.parse(String(contentsOf: url, encoding: .utf8))
                rows = parsed
            } catch { rows = []; message = error.localizedDescription }
        }
        .alert("Calendrier", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
    }
    private func importRows() {
        guard let seasonID = selectedSeason else { return }
        do {
            let result = try CalendarImporter.run(rows: rows, clubID: club.id, seasonID: seasonID, context: context)
            rows = []; message = "\(result.added) matchs importés, \(result.duplicates) doublons ignorés."
        } catch { message = error.localizedDescription }
    }

}


@MainActor
enum CalendarImporter {
    static func run(rows: [CalendarRow], clubID: UUID, seasonID: UUID, context: ModelContext) throws -> (added: Int, duplicates: Int) {
        let seasons = try context.fetch(FetchDescriptor<Season>())
        guard seasons.contains(where: { $0.id == seasonID && $0.clubID == clubID }) else { throw CalendarCSVError.invalid("Saison introuvable.") }
        let teams = try context.fetch(FetchDescriptor<Team>()).filter { $0.clubID == clubID }
        let resolved: [(CalendarRow, Team?)] = try rows.map { row in
            if row.teamName.isEmpty { return (row, nil) }
            let found = teams.filter { $0.name.compare(row.teamName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
            guard found.count == 1 else { throw CalendarCSVError.invalid("Équipe introuvable ou ambiguë : \(row.teamName). Aucun match importé.") }
            return (row, found[0])
        }
        let games = try context.fetch(FetchDescriptor<MatchGame>()).filter { $0.clubID == clubID }
        var known = Set(games.map { game in
            CalendarCSV.key(seasonID: game.seasonID, date: game.date, venue: game.venue, teamID: game.teamID,
                opponent: teams.first(where: { $0.id == game.opponentTeamID })?.name ?? game.opponentName)
        })
        var added = 0, duplicates = 0
        do {
            for (row, team) in resolved {
                let key = CalendarCSV.key(seasonID: seasonID, date: row.date, venue: row.venue, teamID: team?.id, opponent: row.opponent)
                guard known.insert(key).inserted else { duplicates += 1; continue }
                let game = MatchGame(clubID: clubID, seasonID: seasonID, date: row.date, venue: row.venue, totalCost: row.cost)
                game.teamID = team?.id; game.opponentName = row.opponent
                context.insert(game); added += 1
            }
            try context.save()
            return (added, duplicates)
        } catch { context.rollback(); throw error }
    }
}
