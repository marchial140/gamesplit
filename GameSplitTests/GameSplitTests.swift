import XCTest
import SwiftData
@testable import GameSplit

final class GameSplitTests: XCTestCase {
    func testIDEncodingRoundtrip() {
        let ids: Set<UUID> = [UUID(), UUID()]
        XCTAssertEqual(IDList.decode(IDList.encode(ids)), ids)
    }
    func testBalancingKeepsEveryoneAndSimilarCounts() {
        let clubID = UUID()
        let people = (0..<15).map { index in
            Player(clubID: clubID, name: "Person \(index)", position: index < 2 ? "QB" : "WR", overall: 60 + index)
        }
        let result = TeamsBalancer.split(people)
        XCTAssertEqual(result.blue.count + result.red.count, people.count)
        XCTAssertTrue(result.blue.isDisjoint(with: result.red))
        XCTAssertLessThanOrEqual(abs(result.blue.count - result.red.count), 1)
        XCTAssertEqual(result.blue.intersection(Set(people.prefix(2).map(\.id))).count, 1)
        XCTAssertEqual(result.red.intersection(Set(people.prefix(2).map(\.id))).count, 1)
    }
    func testPerPlayerCostWithoutParticipants() {
        let game = MatchGame(clubID: UUID(), seasonID: UUID(), date: .now, venue: "", totalCost: 300)
        XCTAssertEqual(game.costPerPlayer, 0)
    }
}

@MainActor
final class AcceptanceTests: XCTestCase {
    private func fixture() -> (MatchGame, [Player]) {
        let club = UUID()
        let players = (0..<14).map { Player(clubID: club, name: "Joueur \($0)", position: $0 < 2 ? "QB" : "WR", overall: 50 + $0 * 3) }
        let game = MatchGame(clubID: club, seasonID: UUID(), date: .now, venue: "Parc", totalCost: 280)
        let teams = TeamsBalancer.split(players)
        game.blueIDs = teams.blue; game.redIDs = teams.red
        return (game, players)
    }
    func testFourteenPlayersAndPayments() {
        let (game, players) = fixture()
        XCTAssertEqual(game.blueIDs.count, 7)
        XCTAssertEqual(game.redIDs.count, 7)
        XCTAssertEqual(game.participants.count, 14)
        XCTAssertTrue(game.blueIDs.isDisjoint(with: game.redIDs))
        XCTAssertNotEqual(game.blueIDs.contains(players[0].id), game.blueIDs.contains(players[1].id))
        XCTAssertEqual(game.costPerPlayer, 20)
        game.paidIDs = Set(players.prefix(10).map(\.id))
        XCTAssertEqual(game.collected, 200)
        XCTAssertEqual(game.outstanding, 80)
    }
    func testPassingEventAndAtomicCorrection() {
        let (game, players) = fixture()
        let alex = players.first { game.blueIDs.contains($0.id) }!
        let max = players.first { game.blueIDs.contains($0.id) && $0.id != alex.id }!
        let entries = FootballEvents.make(game: game, kind: .passTD, playerID: alex.id, receiverID: max.id)
        FootballEvents.applyScore(kind: .passTD, playerID: alex.id, game: game)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(game.blueScore, 6)
        XCTAssertEqual(Totals.forPlayer(alex.id, games: [game], entries: entries).passTD, 1)
        XCTAssertEqual(Totals.forPlayer(max.id, games: [game], entries: entries).receivingTD, 1)
        XCTAssertEqual(FootballEvents.related(to: entries[1], in: entries).count, 2)
        // Removing both records corrects stats; the official score remains explicit.
        XCTAssertEqual(Totals.forPlayer(max.id, games: [game], entries: []).receivingTD, 0)
        XCTAssertEqual(game.blueScore, 6)
        XCTAssertTrue(FootballEvents.make(game: game, kind: .passTD, playerID: alex.id, receiverID: alex.id).isEmpty)
        let opponent = players.first { game.redIDs.contains($0.id) }!
        XCTAssertTrue(FootballEvents.make(game: game, kind: .passTD, playerID: alex.id, receiverID: opponent.id).isEmpty)
    }
    func testInterceptionTieAndSeasons() {
        let (game, players) = fixture()
        let sam = players[0]
        let entries = FootballEvents.make(game: game, kind: .interception, playerID: sam.id)
        FootballEvents.applyScore(kind: .interception, playerID: sam.id, game: game)
        game.isFinished = true
        let second = MatchGame(clubID: game.clubID, seasonID: game.seasonID, date: .now, venue: "")
        second.blueIDs = [sam.id]; second.blueScore = 12; second.isFinished = true
        let totals = Totals.forPlayer(sam.id, games: [game, second], entries: entries)
        XCTAssertEqual(totals.appearances, 2)
        XCTAssertEqual(totals.wins, 1)
        XCTAssertEqual(totals.interceptions, 1)
        let newSeason = Season(clubID: game.clubID, name: "Nouvelle saison")
        XCTAssertEqual(Totals.forPlayer(sam.id, games: [game, second].filter { $0.seasonID == newSeason.id }, entries: entries).interceptions, 0)
        XCTAssertEqual(game.blueScore, 0)
    }
    func testEdgeCasesAndRules() {
        XCTAssertTrue(TeamsBalancer.split([]).blue.isEmpty)
        let player = Player(clubID: UUID(), name: "Solo")
        let split = TeamsBalancer.split([player, player])
        XCTAssertEqual(split.blue.union(split.red), [player.id])
        let game = MatchGame(clubID: player.clubID, seasonID: UUID(), date: .now, venue: "")
        game.blueIDs = [player.id]
        XCTAssertEqual(game.costPerPlayer, 0)
        game.touchdownPoints = 7; game.conversionPoints = 2
        FootballEvents.applyScore(kind: .rushingTD, playerID: player.id, game: game)
        FootballEvents.applyScore(kind: .conversion, playerID: player.id, game: game)
        XCTAssertEqual(game.blueScore, 9)
        XCTAssertEqual(InputValidation.cost("280,00"), 280)
        for invalid in ["-1", "nan", "inf", "abc", ""] { XCTAssertNil(InputValidation.cost(invalid)) }
        XCTAssertEqual(IDList.decode("invalid," + player.id.uuidString), [player.id])
    }
}

@MainActor
final class PersistenceTests: XCTestCase {
    private var schema: Schema { Schema([Club.self, Season.self, Player.self, MatchGame.self, StatEntry.self]) }
    func testDiskReopenPreservesEditsAndBackupRoundtrip() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.store")
        let id: UUID
        let backupData: Data
        do {
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(url: url)])
            let context = ModelContext(container)
            let club = Club(name: "Amis")
            let season = Season(clubID: club.id, name: "Automne")
            let player = Player(clubID: club.id, name: "Alex")
            let game = MatchGame(clubID: club.id, seasonID: season.id, date: .now, venue: "Parc", totalCost: 20)
            context.insert(club); context.insert(season); context.insert(player); context.insert(game)
            game.blueIDs = [player.id]; game.paidIDs = [player.id]
            player.overall = 91; player.name = "Alex modifié"; game.blueScore = 12; game.isFinished = true
            let entry = FootballEvents.make(game: game, kind: .rushingTD, playerID: player.id)[0]
            context.insert(entry)
            try context.save()
            id = player.id
            backupData = try JSONEncoder().encode(LocalBackup(context: context))
        }
        let reopened = try ModelContainer(for: schema, configurations: [ModelConfiguration(url: url)])
        let context = ModelContext(reopened)
        let player = try XCTUnwrap(context.fetch(FetchDescriptor<Player>()).first)
        XCTAssertEqual(player.id, id); XCTAssertEqual(player.overall, 91); XCTAssertEqual(player.name, "Alex modifié")
        let game = try XCTUnwrap(context.fetch(FetchDescriptor<MatchGame>()).first)
        XCTAssertEqual(game.blueScore, 12); XCTAssertTrue(game.isFinished); XCTAssertEqual(game.collected, 20)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<StatEntry>()), 1)
        let restored = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let destination = ModelContext(restored)
        let backup = try JSONDecoder().decode(LocalBackup.self, from: backupData)
        try backup.restore(context: destination)
        XCTAssertEqual(try destination.fetch(FetchDescriptor<Player>()).first?.id, id)
        XCTAssertEqual(try destination.fetch(FetchDescriptor<MatchGame>()).first?.blueScore, 12)
        XCTAssertEqual(try destination.fetchCount(FetchDescriptor<StatEntry>()), 1)
        XCTAssertThrowsError(try backup.restore(context: destination))
    }
}
