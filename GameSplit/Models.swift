import Foundation
import SwiftData

// IDs and flat, local-only records keep the V1 reliable and allow future multi-sport support.
@Model final class Club {
    var id: UUID
    var name: String
    var localProfileID: UUID? = nil
    var sport: String
    var createdAt: Date
    init(name: String, sport: String = "football") {
        id = UUID(); self.name = name; self.sport = sport; createdAt = .now
    }
}

@Model final class Season {
    var id: UUID
    var clubID: UUID
    var name: String
    var createdAt: Date
    init(clubID: UUID, name: String) {
        id = UUID(); self.clubID = clubID; self.name = name; createdAt = .now
    }
}

@Model final class Player {
    var id: UUID
    var clubID: UUID
    var name: String
    @Attribute(.externalStorage) var photoData: Data? = nil
    var secondaryPositions: String = ""
    var hasNumber: Bool = true
    // Reserved for a verified server association; never populated by a local login.
    var accountID: UUID? = nil
    var position: String
    var number: Int
    var overall: Int
    var createdAt: Date
    init(clubID: UUID, name: String, position: String = "WR", number: Int = 0, overall: Int = 75) {
        id = UUID(); self.clubID = clubID; self.name = name
        self.position = position; self.number = number; self.overall = overall; createdAt = .now
    }
}

@Model final class Team {
    var id: UUID
    var clubID: UUID
    var name: String
    var memberPlayerIDs: String = ""
    var captainPlayerIDs: String = ""
    @Attribute(.externalStorage) var logoData: Data? = nil
    var createdAt: Date
    init(clubID: UUID, name: String) { id = UUID(); self.clubID = clubID; self.name = name; createdAt = .now }
    var memberIDs: Set<UUID> {
        get { IDList.decode(memberPlayerIDs) }
        set { memberPlayerIDs = IDList.encode(newValue) }
    }
    var captainIDs: Set<UUID> {
        get { IDList.decode(captainPlayerIDs) }
        set { captainPlayerIDs = IDList.encode(newValue) }
    }
}

extension Player {
    var positions: Set<String> { Set(secondaryPositions.split(separator: ",").map(String.init)).union([position]) }
    var positionLabel: String { ([position] + positions.subtracting([position]).sorted()).joined(separator: " / ") }
}

@Model final class MatchGame {
    var id: UUID
    var clubID: UUID
    var seasonID: UUID
    var date: Date
    var teamID: UUID? = nil
    var opponentTeamID: UUID? = nil
    var opponentName: String = ""
    var venue: String
    var bluePlayerIDs: String
    var redPlayerIDs: String
    var paidPlayerIDs: String
    var totalCost: Double
    var blueScore: Int
    var redScore: Int
    var touchdownPoints: Int = 6
    var conversionPoints: Int = 1
    var isFinished: Bool

    init(clubID: UUID, seasonID: UUID, date: Date, venue: String, totalCost: Double = 0) {
        id = UUID(); self.clubID = clubID; self.seasonID = seasonID
        self.date = date; self.venue = venue; self.totalCost = totalCost
        bluePlayerIDs = ""; redPlayerIDs = ""; paidPlayerIDs = ""
        blueScore = 0; redScore = 0; isFinished = false
    }
    var blueIDs: Set<UUID> {
        get { IDList.decode(bluePlayerIDs) }
        set { bluePlayerIDs = IDList.encode(newValue) }
    }
    var redIDs: Set<UUID> {
        get { IDList.decode(redPlayerIDs) }
        set { redPlayerIDs = IDList.encode(newValue) }
    }
    var paidIDs: Set<UUID> {
        get { IDList.decode(paidPlayerIDs) }
        set { paidPlayerIDs = IDList.encode(newValue) }
    }
    var participants: Set<UUID> { blueIDs.union(redIDs) }
    var costPerPlayer: Double { participants.isEmpty ? 0 : totalCost / Double(participants.count) }
    var collected: Double { costPerPlayer * Double(paidIDs.intersection(participants).count) }
    var outstanding: Double { max(0, totalCost - collected) }
}

@Model final class StatEntry {
    var id: UUID
    var value: Int = 1
    var eventID: UUID? = nil
    var matchID: UUID
    var playerID: UUID
    var kind: String
    var createdAt: Date
    init(matchID: UUID, playerID: UUID, kind: String) {
        id = UUID(); self.matchID = matchID; self.playerID = playerID
        self.kind = kind; createdAt = .now
    }
}

enum IDList {
    static func decode(_ s: String) -> Set<UUID> {
        Set(s.split(separator: ",").compactMap { UUID(uuidString: String($0)) })
    }
    static func encode(_ ids: Set<UUID>) -> String {
        ids.map(\.uuidString).sorted().joined(separator: ",")
    }
}

enum Position: String, CaseIterable, Identifiable {
    case QB, WR, RB, DB, Rusher, FLEX
    var id: String { rawValue }
}

enum StatKind: String, CaseIterable, Identifiable {
    case passTD = "pass_td"
    case receivingTD = "receiving_td"
    case rushingTD = "rushing_td"
    case interception = "interception"
    case conversion = "conversion"
    case passingYards = "passing_yards"
    case receivingYards = "receiving_yards"
    case thrownInterception = "thrown_interception"
    case reception = "reception"
    case tackle = "tackle"
    case sack = "sack"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .passTD: "Passe TD"
        case .receivingTD: "Réception TD"
        case .rushingTD: "Course TD"
        case .interception: "Interception défensive"
        case .conversion: "Conversion réussie"
        case .passingYards: "Verges par la passe"
        case .receivingYards: "Verges de réception"
        case .thrownInterception: "Interception lancée"
        case .reception: "Réception (hors TD)"
        case .tackle: "Plaqué"
        case .sack: "Sac du quart"
        }
    }
}

struct PlayerTotals {
    var passTD = 0
    var receivingTD = 0
    var rushingTD = 0
    var interceptions = 0
    var conversions = 0
    var passingYards = 0
    var receivingYards = 0
    var thrownInterceptions = 0
    var receptions = 0
    var tackles = 0
    var sacks = 0
    var appearances = 0
    var wins = 0
    var touchdowns: Int { receivingTD + rushingTD }
    var contributionPoints: Int { ContributionRules.points(self) }
}

enum Totals {
    static func forPlayer(_ id: UUID, games: [MatchGame], entries: [StatEntry]) -> PlayerTotals {
        byPlayer(games: games, entries: entries)[id] ?? PlayerTotals()
    }
    static func byPlayer(games: [MatchGame], entries: [StatEntry]) -> [UUID: PlayerTotals] {
        var result: [UUID: PlayerTotals] = [:]
        let gameIDs = Set(games.map(\.id))
        for entry in entries where gameIDs.contains(entry.matchID) {
            var total = result[entry.playerID] ?? PlayerTotals()
            switch entry.kind {
            case StatKind.passTD.rawValue: total.passTD += entry.value
            case StatKind.receivingTD.rawValue: total.receivingTD += entry.value; total.receptions += entry.value
            case StatKind.rushingTD.rawValue: total.rushingTD += entry.value
            case StatKind.interception.rawValue: total.interceptions += entry.value
            case StatKind.conversion.rawValue: total.conversions += entry.value
            case StatKind.passingYards.rawValue: total.passingYards += entry.value
            case StatKind.receivingYards.rawValue: total.receivingYards += entry.value
            case StatKind.thrownInterception.rawValue: total.thrownInterceptions += entry.value
            case StatKind.reception.rawValue: total.receptions += entry.value
            case StatKind.tackle.rawValue: total.tackles += entry.value
            case StatKind.sack.rawValue: total.sacks += entry.value
            default: break
            }
            result[entry.playerID] = total
        }
        for game in games where game.isFinished {
            for id in game.participants {
                var total = result[id] ?? PlayerTotals()
                total.appearances += 1
                if game.blueScore != game.redScore &&
                    ((game.blueScore > game.redScore && game.blueIDs.contains(id)) ||
                     (game.redScore > game.blueScore && game.redIDs.contains(id))) { total.wins += 1 }
                result[id] = total
            }
        }
        return result
    }
}

enum TeamsBalancer {
    /// Greedy OVR balance with an early QB split; intended for recreational games.
    static func split(_ players: [Player]) -> (blue: Set<UUID>, red: Set<UUID>) {
        let unique = Dictionary(players.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let sorted = unique.values.sorted {
            if ($0.positions.contains("QB")) != ($1.positions.contains("QB")) { return $0.positions.contains("QB") }
            if $0.overall != $1.overall { return $0.overall > $1.overall }
            return $0.id.uuidString < $1.id.uuidString
        }
        var blue = Set<UUID>(), red = Set<UUID>()
        var blueScore = 0, redScore = 0
        let blueCapacity = (sorted.count + 1) / 2
        let redCapacity = sorted.count / 2
        for player in sorted {
            let chooseBlue: Bool
            if blue.count >= blueCapacity { chooseBlue = false }
            else if red.count >= redCapacity { chooseBlue = true }
            else if player.positions.contains("QB") {
                let qbBlue = sorted.filter { $0.positions.contains("QB") && blue.contains($0.id) }.count
                let qbRed = sorted.filter { $0.positions.contains("QB") && red.contains($0.id) }.count
                chooseBlue = qbBlue == qbRed ? blueScore <= redScore : qbBlue < qbRed
            } else { chooseBlue = blueScore <= redScore }
            if chooseBlue { blue.insert(player.id); blueScore += player.overall }
            else { red.insert(player.id); redScore += player.overall }
        }
        // Improve OVR differences by swaps, preserving sizes and QB distribution.
        var improved = true
        while improved {
            improved = false
            let difference = abs(blueScore - redScore)
            var best = difference
            var swap: (Player, Player)?
            for b in sorted where blue.contains(b.id) {
                for r in sorted where red.contains(r.id) {
                    guard (b.positions.contains("QB")) == (r.positions.contains("QB")) else { continue }
                    let candidate = abs((blueScore - b.overall + r.overall) - (redScore - r.overall + b.overall))
                    if candidate < best { best = candidate; swap = (b, r) }
                }
            }
            if let (b, r) = swap {
                blue.remove(b.id); red.remove(r.id); blue.insert(r.id); red.insert(b.id)
                blueScore += r.overall - b.overall; redScore += b.overall - r.overall
                improved = true
            }
        }
        return (blue, red)
    }
}

/// A pass and its reception form one atomic event. Official scores remain independently editable.
enum FootballEvents {
    static func make(game: MatchGame, kind: StatKind, playerID: UUID, receiverID: UUID? = nil, value: Int = 1) -> [StatEntry] {
        guard game.participants.contains(playerID), (1...10_000).contains(value) else { return [] }
        if kind == .passTD {
            guard let receiverID, receiverID != playerID,
                  (game.blueIDs.contains(playerID) && game.blueIDs.contains(receiverID)) ||
                  (game.redIDs.contains(playerID) && game.redIDs.contains(receiverID)) else { return [] }
            let eventID = UUID()
            let pass = StatEntry(matchID: game.id, playerID: playerID, kind: kind.rawValue)
            let reception = StatEntry(matchID: game.id, playerID: receiverID, kind: StatKind.receivingTD.rawValue)
            pass.eventID = eventID; reception.eventID = eventID
            pass.value = value; reception.value = value
            return [pass, reception]
        }
        let entry = StatEntry(matchID: game.id, playerID: playerID, kind: kind.rawValue)
        entry.value = value
        return [entry]
    }
    static func points(kind: StatKind, game: MatchGame) -> Int {
        switch kind {
        case .passTD, .receivingTD, .rushingTD: return game.touchdownPoints
        case .conversion: return game.conversionPoints
        default: return 0
        }
    }
    static func applyScore(kind: StatKind, playerID: UUID, game: MatchGame, value: Int = 1) {
        guard (1...10_000).contains(value), game.participants.contains(playerID) else { return }
        let award = points(kind: kind, game: game) * value
        if game.blueIDs.contains(playerID) { game.blueScore += award }
        else if game.redIDs.contains(playerID) { game.redScore += award }
    }
    static func related(to entry: StatEntry, in entries: [StatEntry]) -> [StatEntry] {
        entries.filter { candidate in
            candidate.id == entry.id || (entry.eventID != nil && candidate.eventID == entry.eventID && candidate.matchID == entry.matchID)
        }
    }
}

enum InputValidation {
    static func cost(_ text: String) -> Double? {
        guard let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")),
              value.isFinite, value >= 0, value <= 1_000_000 else { return nil }
        return (value * 100).rounded() / 100
    }
}


enum ContributionRules {
    static let passingTouchdown = 4
    static func points(_ totals: PlayerTotals) -> Int {
        totals.touchdowns * 6 + totals.passTD * passingTouchdown + totals.interceptions * 2 + totals.conversions
    }
}

struct TeamRecordSummary {
    var played = 0
    var wins = 0
    var losses = 0
    var ties = 0
    var pointsFor = 0
    var pointsAgainst = 0
    static func calculate(teamID: UUID, games: [MatchGame]) -> TeamRecordSummary {
        var result = TeamRecordSummary()
        for game in games where game.isFinished && (game.teamID == teamID || game.opponentTeamID == teamID) {
            let home = game.teamID == teamID
            let scored = home ? game.blueScore : game.redScore
            let allowed = home ? game.redScore : game.blueScore
            result.played += 1; result.pointsFor += scored; result.pointsAgainst += allowed
            if scored > allowed { result.wins += 1 }
            else if scored < allowed { result.losses += 1 }
            else { result.ties += 1 }
        }
        return result
    }
}

/// Shared by creation, roster edits and CSV import; never mutates historical records.
enum MatchValidation {
    static func isOfficial(teamID: UUID?, opponentTeamID: UUID?) -> Bool {
        teamID != nil || opponentTeamID != nil
    }
    static func canAutoBalance(_ game: MatchGame) -> Bool {
        !isOfficial(teamID: game.teamID, opponentTeamID: game.opponentTeamID)
    }
    static func issue(clubID: UUID, teamID: UUID?, opponentTeamID: UUID?, opponentName: String,
                      blue: Set<UUID>, red: Set<UUID>, teams: [Team], players: [Player],
                      requireRecreationalParticipants: Bool = true, checkCurrentMembership: Bool = true) -> String? {
        let validPlayers = Set(players.filter { $0.clubID == clubID }.map(\.id))
        guard blue.isDisjoint(with: red) else { return "Un joueur ne peut pas être présent dans les deux camps." }
        guard blue.union(red).isSubset(of: validPlayers) else { return "Certains participants ne font pas partie de cette organisation." }
        guard isOfficial(teamID: teamID, opponentTeamID: opponentTeamID) else {
            return requireRecreationalParticipants && (blue.isEmpty || red.isEmpty) ? "Sélectionnez au moins un joueur dans chaque camp." : nil
        }
        guard let teamID, let home = teams.first(where: { $0.id == teamID && $0.clubID == clubID && !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { return "Choisissez une équipe valide pour ce match officiel." }
        if let opponentTeamID {
            guard teamID != opponentTeamID else { return "Une équipe ne peut pas jouer contre elle-même." }
            guard let away = teams.first(where: { $0.id == opponentTeamID && $0.clubID == clubID && !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { return "L’équipe adverse n’est pas valide." }
            guard !checkCurrentMembership || red.isSubset(of: away.memberIDs) else { return "Les joueurs adverses doivent appartenir à l’équipe adverse." }
        } else if opponentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Indiquez le nom de l’adversaire ou choisissez une équipe."
        }
        guard !checkCurrentMembership || blue.isSubset(of: home.memberIDs) else { return "Les joueurs de votre camp doivent appartenir à votre équipe." }
        guard !blue.isEmpty, !red.isEmpty else { return "Un match officiel exige au moins un participant dans chaque camp. Ajoutez les joueurs adverses à l’effectif si nécessaire." }
        return nil
    }
}

/// Rankings never turn registered players without completed games into leaders.
enum PerformanceEligibility {
    static func hasPerformance(_ totals: PlayerTotals, position: String? = nil) -> Bool {
        guard totals.appearances > 0 else { return false }
        switch position {
        case "QB": return totals.passTD > 0 || totals.passingYards > 0 || totals.thrownInterceptions > 0
        case "WR": return totals.receivingTD > 0 || totals.receivingYards > 0 || totals.receptions > 0
        case "DB": return totals.interceptions > 0 || totals.tackles > 0
        case "Rusher": return totals.sacks > 0 || totals.tackles > 0
        default: return true
        }
    }
}

struct PerformanceRecord: Identifiable {
    let kind: StatKind
    let value: Int
    var id: String { kind.rawValue }
}

enum PersonalRecords {
    static func best(playerID: UUID, games: [MatchGame], entries: [StatEntry]) -> [PerformanceRecord] {
        let ids = Set(games.filter { $0.isFinished && $0.participants.contains(playerID) }.map(\.id))
        var byGame: [UUID: [String: Int]] = [:]
        for entry in entries where entry.playerID == playerID && ids.contains(entry.matchID) {
            byGame[entry.matchID, default: [:]][entry.kind, default: 0] += entry.value
        }
        let kinds: [StatKind] = [.passTD, .passingYards, .receivingTD, .receivingYards, .rushingTD, .interception, .tackle, .sack]
        return kinds.compactMap { kind in
            let best = byGame.values.map { $0[kind.rawValue] ?? 0 }.max() ?? 0
            return best > 0 ? PerformanceRecord(kind: kind, value: best) : nil
        }
    }
}
