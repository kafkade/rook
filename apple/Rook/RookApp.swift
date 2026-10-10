import SwiftUI
import RookKit

@main
struct RookApp: App {
    @StateObject private var model = RookModel()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RookRoot().environmentObject(model).tint(RookColor.accent)
                .preferredColorScheme(testAppearance)
                .onChange(of: phase) { _, phase in model.sceneChanged(phase) }
        }
    }

    private var testAppearance: ColorScheme? {
        #if DEBUG
        if ProcessInfo.processInfo.environment["ROOK_TEST_ID"] != nil {
            switch ProcessInfo.processInfo.environment["ROOK_TEST_APPEARANCE"] {
            case "dark": return .dark
            case "light": return .light
            default: return nil
            }
        }
        #endif
        return nil
    }
}

struct RookRoot: View {
    @EnvironmentObject private var model: RookModel

    var body: some View {
        ZStack {
            Group {
                if model.snapshot != nil {
                    TabView {
                        NavigationStack { RoutinesView() }
                            .tabItem { Label("Routines", systemImage: "square.stack") }
                        NavigationStack { HistoryView() }
                            .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                        NavigationStack { ProgressViewPage() }
                            .tabItem { Label("Progress", systemImage: "chart.xyaxis.line") }
                        NavigationStack { SettingsView() }
                            .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
                    }
                } else if let error = model.startupError {
                    ContentUnavailableView {
                        Label("Rook couldn't open", systemImage: "lock.trianglebadge.exclamationmark")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Try again") { Task { await model.open() } }.rookPrimary()
                        Button("Restore a backup") { model.showsImport = true }
                            .buttonStyle(.bordered)
                    }
                } else {
                    ProgressView("Opening your encrypted journal")
                }
            }
            .accessibilityHidden(model.privacyCover)
            if model.privacyCover {
                RookColor.canvas.ignoresSafeArea()
                VStack(spacing: 16) {
                    Image(systemName: "lock.fill").font(.largeTitle)
                    Text("Rook").font(.title.bold())
                    Text("Your training stays private.").foregroundStyle(RookColor.secondary)
                }
            }
        }
        .background(RookColor.canvas)
        .task { await model.open() }
        .fullScreenCover(isPresented: $model.showsWorkout) {
            NavigationStack { ActiveWorkoutView() }.rookPrivacyCover().rookIssueHost()
        }
        .fileImporter(isPresented: $model.showsImport, allowedContentTypes: [.data]) { result in
            switch result {
            case .success(let url):
                model.restoreURL = url
                model.showsRestore = true
            case .failure(let error):
                model.report(error)
            }
        }
        .sheet(isPresented: $model.showsRestore) {
            if let url = model.restoreURL {
                NavigationStack { RestoreBackupView(url: url) }.rookPrivacyCover().rookIssueHost()
            }
        }
        .rookIssueHost(active: !model.showsWorkout && !model.showsRestore && !model.hasRoutineEditor)
    }
}

private struct RoutineEditorChoice: Identifiable {
    let id = UUID()
    let routine: Routine?
}

struct RoutinesView: View {
    @EnvironmentObject private var model: RookModel
    @State private var editor: RoutineEditorChoice?
    @State private var delete: Routine?

    var body: some View {
        List {
            if let active = model.snapshot?.active {
                Section {
                    Button {
                        model.showsWorkout = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "play.circle.fill").font(.title2)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Resume \(active.routineName)").font(.headline)
                                Text("\(active.completedSets) sets complete")
                                    .font(.subheadline).foregroundStyle(RookColor.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                        }.padding(.vertical, 6)
                    }
                    .accessibilityIdentifier("resume-workout")
                }
                .listRowBackground(RookColor.surface)
            }
            if model.snapshot?.routines.isEmpty == true {
                Section {
                    VStack(alignment: .leading, spacing: 18) {
                        Image(systemName: "square.stack").font(.largeTitle).foregroundStyle(RookColor.accent)
                        Text("Your next mark starts here.").font(.title2.bold())
                        Text("Create a routine, log your sets, and return to a record that's yours.")
                            .foregroundStyle(RookColor.secondary)
                        Button("Create a routine") { editor = RoutineEditorChoice(routine: nil) }
                            .rookPrimary().accessibilityIdentifier("create-first-routine")
                        Button("Add an example routine") { Task { await model.addExample() } }
                            .buttonStyle(.bordered).accessibilityIdentifier("add-example")
                        Text("Structure only. Choose your own exercises and weights before training.")
                            .font(.footnote).foregroundStyle(RookColor.secondary)
                    }.padding(.vertical, 14)
                }.listRowBackground(RookColor.surface)
            } else {
                Section("Your routines") {
                    ForEach(model.snapshot?.routines ?? [], id: \.id) { routine in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(routine.name).font(.title3.bold())
                                    Text("\(routine.exercises.count) exercises · \(routine.exercises.reduce(0) { $0 + Int($1.sets) }) planned sets")
                                        .font(.subheadline).foregroundStyle(RookColor.secondary)
                                }
                                Spacer(minLength: 8)
                                Menu {
                                    Button("Edit routine", systemImage: "pencil") {
                                        editor = RoutineEditorChoice(routine: routine)
                                    }
                                    Button("Delete routine", systemImage: "trash", role: .destructive) {
                                        delete = routine
                                    }
                                } label: {
                                    Image(systemName: "ellipsis").frame(minWidth: 44, minHeight: 44)
                                }
                                .accessibilityLabel("Actions for \(routine.name)")
                            }
                            Button {
                                Task {
                                    if await model.perform(.startWorkout(routine.id)) { model.showsWorkout = true }
                                }
                            } label: {
                                Label("Start workout", systemImage: "play.fill").frame(maxWidth: .infinity)
                            }
                            .rookPrimary().accessibilityIdentifier("start-workout")
                            .disabled(model.snapshot?.active != nil)
                        }.padding(.vertical, 8)
                    }
                }.listRowBackground(RookColor.surface)
            }
            Section {
                Text("Always learning. Always your record.")
                    .font(.footnote).foregroundStyle(RookColor.secondary)
            }.listRowBackground(Color.clear)
        }
        .rookList().navigationTitle("Rook")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New routine", systemImage: "plus") { editor = RoutineEditorChoice(routine: nil) }
                    .accessibilityIdentifier("new-routine")
            }
        }
        .disabled(model.busy)
        .sheet(item: $editor, onDismiss: { model.hasRoutineEditor = false }) { choice in
            NavigationStack { RoutineEditor(routine: choice.routine, unit: model.unit) }
                .rookPrivacyCover().rookIssueHost()
                .onAppear { model.hasRoutineEditor = true }
        }
        .alert("Delete this routine?", isPresented: Binding(
            get: { delete != nil }, set: { if !$0 { delete = nil } }
        )) {
            Button("Cancel", role: .cancel) { delete = nil }
            Button("Delete routine", role: .destructive) {
                if let routine = delete { Task { _ = await model.perform(.deleteRoutine(routine.id)) } }
                delete = nil
            }
        } message: { Text("Completed workouts and your active session will remain unchanged.") }
    }
}
