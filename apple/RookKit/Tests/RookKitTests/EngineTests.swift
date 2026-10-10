import Foundation
import XCTest
@testable import RookKit

final class EngineTests: XCTestCase {
    func testTypedBindingsPersistAndRestoreAnActiveWorkout() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rook-bindings-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            do { try FileManager.default.removeItem(at: directory) }
            catch { XCTFail("Could not clean the synthetic test directory: \(error)") }
        }
        let engine = try RookEngine(
            path: directory.appendingPathComponent("original.sqlite").path,
            key: Data(repeating: 7, count: 32)
        )
        let plan = ExerciseDraft(
            id: nil, name: "Synthetic press", sets: 3, reps: 8,
            weightKg: 60, restSeconds: 90
        )
        let routine = try XCTUnwrap(engine.saveRoutine(id: nil, name: "Synthetic routine", exercises: [plan]).routines.first)
        let active = try XCTUnwrap(engine.startWorkout(routineId: routine.id).active)
        let set = try XCTUnwrap(active.exercises.first?.sets.first)
        let logged = try engine.updateSet(setId: set.id, weight: 135, unit: .lb, reps: 8, completed: true)
        XCTAssertEqual(logged.active?.completedSets, 1)
        XCTAssertNotNil(logged.active?.restEndMs)
        let backup = try engine.exportBackup(passphrase: "synthetic binding backup phrase")
        let recovered = try RookEngine.createRestored(
            path: directory.appendingPathComponent("recovered.sqlite").path,
            key: Data(repeating: 9, count: 32),
            ciphertext: backup,
            passphrase: "synthetic binding backup phrase"
        )
        XCTAssertEqual(try recovered.readSnapshot().active?.id, active.id)
        XCTAssertEqual(try recovered.readSnapshot().active?.completedSets, 1)
        XCTAssertEqual(try displayWeight(weightKg: 61.23496995, unit: .lb), 135, accuracy: 0.000001)
        try recovered.close()
        try engine.close()
        XCTAssertThrowsError(try engine.readSnapshot())
    }
}
