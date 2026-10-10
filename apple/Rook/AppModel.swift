import Combine
import Foundation
import RookKit
import SwiftUI
import UserNotifications

struct RookIssue: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct SetEdit: Equatable {
    let id: String
    let weight: String
    let reps: String
    let unit: WeightUnit
}

enum RookNumber {
    static func parse(_ text: String) throws -> Double {
        let decimal = Locale.current.decimalSeparator ?? "."
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: decimal, with: ".")
        guard let value = Double(cleaned), value.isFinite else {
            throw StorageFailure.message("Enter a valid weight.")
        }
        return value
    }

    static func reps(_ text: String) throws -> UInt32 {
        guard let value = UInt32(text.trimmingCharacters(in: .whitespacesAndNewlines)), value > 0 else {
            throw StorageFailure.message("Enter a positive whole number of repetitions.")
        }
        return value
    }

    static func weight(_ kg: Double, unit: WeightUnit) -> String {
        do {
            return try displayWeight(weightKg: kg, unit: unit)
                .formatted(.number.grouping(.never).precision(.fractionLength(0...2)))
        } catch {
            return "Invalid weight"
        }
    }

    static func editWeight(_ kg: Double, unit: WeightUnit) -> String {
        do {
            return String(try displayWeight(weightKg: kg, unit: unit))
                .replacingOccurrences(of: ".", with: Locale.current.decimalSeparator ?? ".")
        } catch {
            return "Invalid weight"
        }
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let whole = Int(max(0, seconds))
        return String(format: "%02lld:%02lld", Int64(whole / 60), Int64(whole % 60))
    }

    static func date(_ milliseconds: Int64) -> Date {
        Date(timeIntervalSince1970: Double(milliseconds) / 1000)
    }
}

@MainActor
final class RookModel: ObservableObject {
    @Published private(set) var snapshot: Snapshot?
    @Published private(set) var busy = false
    @Published private(set) var opening = false
    @Published private(set) var privacyCover = false
    @Published var issue: RookIssue?
    @Published var startupError: String?
    @Published var showsWorkout = false
    @Published var showsImport = false
    @Published var restoreURL: URL?
    @Published var showsRestore = false
    @Published var hasRoutineEditor = false
    private(set) var edits: [String: SetEdit] = [:]
    private let repository = RookRepository()
    private var latestSequence: UInt64 = 0
    private var draftTask: Task<Void, Never>?
    private var scheduledRest: Int64?
    private var scheduledAlerts = false

    var unit: WeightUnit { snapshot?.unit ?? .kg }
    var unitLabel: String { unit == .kg ? "kg" : "lb" }

    private func apply(_ update: StoreUpdate) {
        guard update.sequence > latestSequence, !privacyCover else { return }
        latestSequence = update.sequence
        snapshot = update.snapshot
        startupError = nil
        if update.snapshot.active == nil { showsWorkout = false }
    }

    func open() async {
        guard !opening else { return }
        opening = true
        privacyCover = false
        do {
            apply(try await repository.open())
            await syncRestAlert()
        } catch {
            startupError = error.localizedDescription
        }
        opening = false
    }

    func sceneChanged(_ phase: ScenePhase) {
        switch phase {
        case .active:
            privacyCover = false
            Task { await open() }
        case .inactive:
            privacyCover = true
        case .background:
            privacyCover = true
            draftTask?.cancel()
            Task {
                do { try await flushEdits(); try await repository.close() }
                catch {
                    issue = RookIssue(
                        title: "Changes need attention",
                        message: "Some edits could not be saved before locking. Unlock and retry. \(error.localizedDescription)"
                    )
                    do { try await repository.close() }
                    catch { startupError = error.localizedDescription }
                }
            }
        @unknown default:
            privacyCover = true
        }
    }

    func queueEdit(_ edit: SetEdit) {
        edits[edit.id] = edit
        draftTask?.cancel()
        draftTask = Task {
            do { try await Task.sleep(for: .milliseconds(350)) }
            catch is CancellationError { return }
            catch { report(error) ; return }
            // Partial keyboard input stays visible until it is a valid committed value.
            guard (try? RookNumber.parse(edit.weight)) != nil,
                  (try? RookNumber.reps(edit.reps)) != nil else { return }
            do { try await flushEdits() }
            catch { report(error) }
        }
    }

    func text(for set: WorkoutSet) -> (weight: String, reps: String) {
        if let edit = edits[set.id] { return (edit.weight, edit.reps) }
        return (RookNumber.editWeight(set.weightKg, unit: unit), String(set.reps))
    }

    func flushEdits() async throws {
        let pending = Array(edits.values)
        for edit in pending {
            let weight = try RookNumber.parse(edit.weight)
            let reps = try RookNumber.reps(edit.reps)
            let update = try await repository.perform(.updateSet(edit.id, weight, edit.unit, reps, nil))
            if edits[edit.id] == edit { edits.removeValue(forKey: edit.id) }
            apply(update)
        }
    }

    @discardableResult
    func perform(_ command: EngineCommand) async -> Bool {
        guard !busy, !privacyCover else { return false }
        busy = true
        draftTask?.cancel()
        do {
            try await flushEdits()
            apply(try await repository.perform(command))
            await syncRestAlert()
            busy = false
            return true
        } catch {
            busy = false
            report(error)
            return false
        }
    }

    func commitSet(id: String, completed: Bool) async {
        _ = await perform(.setCompleted(id, completed))
    }

    func closeWorkout() async {
        do { try await flushEdits(); showsWorkout = false }
        catch { report(error) }
    }

    func addExample() async {
        let exercises = [
            ExerciseDraft(id: nil, name: "Bench press", sets: 3, reps: 8, weightKg: 0, restSeconds: 90),
            ExerciseDraft(id: nil, name: "Seated row", sets: 3, reps: 10, weightKg: 0, restSeconds: 90),
            ExerciseDraft(id: nil, name: "Overhead press", sets: 3, reps: 8, weightKg: 0, restSeconds: 90)
        ]
        _ = await perform(.saveRoutine(nil, "Upper body", exercises))
    }

    func changeAlerts(_ enabled: Bool) async {
        if enabled {
            do {
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound])
                guard granted else {
                    issue = RookIssue(
                        title: "Rest alerts are off",
                        message: "Notification permission was not granted. The in-app timer still works. You can enable alerts in iPhone Settings."
                    )
                    return
                }
            } catch { report(error); return }
        }
        do {
            try await flushEdits()
            apply(try await repository.perform(.settings(unit, enabled)))
            await syncRestAlert()
        } catch { report(error) }
    }

    private func syncRestAlert() async {
        let end = snapshot?.active?.restEndMs
        let enabled = snapshot?.restAlerts == true
        guard end != scheduledRest || enabled != scheduledAlerts else { return }
        scheduledRest = end
        scheduledAlerts = enabled
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["rook.rest"])
        guard enabled, let end else { return }
        let interval = RookNumber.date(end).timeIntervalSinceNow
        guard interval > 0 else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            issue = RookIssue(
                title: "Rest alert unavailable",
                message: "Your workout is saved, but notifications are disabled in iPhone Settings."
            )
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "Rest finished"
        content.body = "Return when you're ready."
        content.sound = .default
        do {
            try await center.add(UNNotificationRequest(
                identifier: "rook.rest", content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, interval), repeats: false)
            ))
        } catch {
            issue = RookIssue(
                title: "Rest alert unavailable",
                message: "Your workout is saved. \(error.localizedDescription)"
            )
        }
    }

    func export(passphrase: String) async -> Data? {
        guard !busy else { return nil }
        busy = true
        defer { busy = false }
        do {
            try await flushEdits()
            return try await repository.export(passphrase: passphrase)
        } catch { report(error); return nil }
    }

    func restore(url: URL, passphrase: String) async -> Bool {
        guard !busy else { return false }
        busy = true
        defer { busy = false }
        draftTask?.cancel()
        do {
            let data = try await repository.readBackup(at: url)
            let update = try await repository.restore(data: data, passphrase: passphrase, confirmed: true)
            edits.removeAll()
            apply(update)
            await syncRestAlert()
            return true
        } catch { report(error); return false }
    }

    func report(_ error: Error) {
        issue = RookIssue(title: "Rook couldn't complete that", message: error.localizedDescription)
    }
}
