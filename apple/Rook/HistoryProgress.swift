import SwiftUI
import Charts
import RookKit

struct HistoryView: View {
    @EnvironmentObject private var model: RookModel
    @State private var deleting: Workout?

    var body: some View {
        List {
            if model.snapshot?.history.isEmpty == true {
                ContentUnavailableView(
                    "Your story starts with a session", systemImage: "clock.arrow.circlepath",
                    description: Text("Finish a workout to keep its sets, weights, and repetitions here.")
                ).listRowBackground(Color.clear)
            }
            ForEach(model.snapshot?.history ?? [], id: \.id) { workout in
                NavigationLink {
                    WorkoutHistoryDetail(workout: workout)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(workout.routineName).font(.headline)
                        Text(RookNumber.date(workout.startedMs), format: .dateTime.month(.abbreviated).day().year())
                            .font(.subheadline).foregroundStyle(RookColor.secondary)
                        Text("\(workout.completedSets) sets · \(RookNumber.weight(workout.volumeKg, unit: model.unit)) \(model.unitLabel) volume")
                            .font(.subheadline.monospacedDigit())
                    }.padding(.vertical, 6)
                }
                .listRowBackground(RookColor.surface)
                .swipeActions {
                    Button("Delete", systemImage: "trash", role: .destructive) { deleting = workout }
                }
            }
        }
        .rookList().navigationTitle("History")
        .alert("Delete this workout?", isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } }
        )) {
            Button("Cancel", role: .cancel) { deleting = nil }
            Button("Delete workout", role: .destructive) {
                if let workout = deleting { Task { _ = await model.perform(.deleteWorkout(workout.id)) } }
                deleting = nil
            }
        } message: { Text("This removes the completed session from this device. Your routines remain.") }
    }
}

struct WorkoutHistoryDetail: View {
    @EnvironmentObject private var model: RookModel
    let workout: Workout

    var body: some View {
        List {
            Section {
                LabeledContent("Started", value: RookNumber.date(workout.startedMs).formatted(date: .abbreviated, time: .shortened))
                if let end = workout.finishedMs {
                    LabeledContent("Duration", value: RookNumber.clock(Double(end - workout.startedMs) / 1000))
                }
                LabeledContent("Completed sets", value: String(workout.completedSets))
                LabeledContent("Volume", value: "\(RookNumber.weight(workout.volumeKg, unit: model.unit)) \(model.unitLabel)")
            }.listRowBackground(RookColor.surface)
            ForEach(workout.exercises, id: \.id) { exercise in
                Section(exercise.name) {
                    let completed = exercise.sets.enumerated().filter { $0.element.completed }
                    if completed.isEmpty {
                        Text("No sets completed").foregroundStyle(RookColor.secondary)
                    }
                    ForEach(completed, id: \.element.id) { index, set in
                        LabeledContent(
                            "Set \(index + 1)",
                            value: "\(RookNumber.weight(set.weightKg, unit: model.unit)) \(model.unitLabel) × \(set.reps)"
                        ).monospacedDigit()
                    }
                }.listRowBackground(RookColor.surface)
            }
            Section {
                Text("This is the record as it was saved. Later routine changes do not rewrite it.")
                    .font(.footnote).foregroundStyle(RookColor.secondary)
            }.listRowBackground(Color.clear)
        }
        .rookList().navigationTitle(workout.routineName).navigationBarTitleDisplayMode(.inline)
    }
}

private struct ExerciseSeries: Identifiable {
    let id: String
    let label: String
}

private struct ProgressPoint: Identifiable {
    let id: String
    let date: Date
    let weightKg: Double
    let reps: UInt64
}

private struct ChartDatum: Identifiable {
    let id: String
    let date: Date
    let value: Double
}

struct ProgressViewPage: View {
    @EnvironmentObject private var model: RookModel
    @State private var selected = ""
    @State private var metric = 0

    private var series: [ExerciseSeries] {
        var seen = Set<String>()
        var result: [ExerciseSeries] = []
        for workout in model.snapshot?.history ?? [] {
            for exercise in workout.exercises where seen.insert(exercise.templateId).inserted {
                result.append(ExerciseSeries(id: exercise.templateId, label: "\(exercise.name) · \(workout.routineName)"))
            }
        }
        return result.sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
    }

    private var points: [ProgressPoint] {
        (model.snapshot?.history ?? []).reversed().compactMap { workout in
            guard let exercise = workout.exercises.first(where: { $0.templateId == selected }) else { return nil }
            let sets = exercise.sets.filter(\.completed)
            guard let maximum = sets.map(\.weightKg).max() else { return nil }
            return ProgressPoint(
                id: workout.id, date: RookNumber.date(workout.startedMs),
                weightKg: maximum, reps: sets.reduce(0) { $0 + UInt64($1.reps) }
            )
        }
    }

    var body: some View {
        List {
            if model.snapshot?.history.isEmpty == true {
                ContentUnavailableView(
                    "Progress needs a starting point", systemImage: "chart.xyaxis.line",
                    description: Text("Completed workouts will become your own comparison—not somebody else's benchmark.")
                ).listRowBackground(Color.clear)
            } else {
                Section("Your recorded work") {
                    LabeledContent("Workouts", value: String(model.snapshot?.history.count ?? 0))
                    LabeledContent("Completed sets", value: String((model.snapshot?.history ?? []).reduce(UInt64(0)) { $0 + UInt64($1.completedSets) }))
                }.listRowBackground(RookColor.surface)
                Section {
                    Picker("Exercise", selection: $selected) {
                        Text("Choose an exercise").tag("")
                        ForEach(series) { exercise in Text(exercise.label).tag(exercise.id) }
                    }
                    Picker("Measure", selection: $metric) {
                        Text("Top weight").tag(0)
                        Text("Reps").tag(1)
                    }.pickerStyle(.segmented)
                    if !points.isEmpty {
                        switch chartData {
                        case .success(let data):
                            Chart(data) { point in
                                if metric == 0 {
                                    LineMark(
                                        x: .value("Date", point.date),
                                        y: .value(model.unitLabel, point.value)
                                    ).symbol(.circle).foregroundStyle(RookColor.accent)
                                } else {
                                    BarMark(x: .value("Date", point.date), y: .value("Completed reps", point.value))
                                        .foregroundStyle(RookColor.accent)
                                }
                            }
                            .chartYScale(domain: .automatic(includesZero: true))
                            .chartYAxisLabel(metric == 0 ? model.unitLabel : "Completed reps")
                            .frame(height: 220).padding(.vertical, 12)
                            .accessibilityLabel(metric == 0 ? "Top recorded weight per workout" : "Completed repetitions per workout")
                        case .failure(let error):
                            Text("\(error.localizedDescription) The original records remain in History.")
                                .foregroundStyle(.red)
                        }
                        ForEach(points.reversed()) { point in
                            LabeledContent {
                                Text(metric == 0
                                     ? "\(RookNumber.weight(point.weightKg, unit: model.unit)) \(model.unitLabel)"
                                     : "\(point.reps) reps")
                            } label: {
                                Text(point.date, format: .dateTime.month(.abbreviated).day())
                            }.monospacedDigit()
                        }
                    }
                } header: {
                    Text("One mark at a time")
                } footer: {
                    Text("Series follow an exercise within a routine, including renames. Only completed sets count; no added weight is recorded as zero.")
                }
                .listRowBackground(RookColor.surface)
            }
        }
        .rookList().navigationTitle("Progress")
        .onAppear { if selected.isEmpty { selected = series.first?.id ?? "" } }
        .onChange(of: series.map(\.id)) { _, ids in
            if !ids.contains(selected) { selected = ids.first ?? "" }
        }
    }

    private var chartData: Result<[ChartDatum], Error> {
        Result {
            try points.map { point in
                let value = metric == 1 ? Double(point.reps) : try displayWeight(weightKg: point.weightKg, unit: model.unit)
                guard value <= Double.greatestFiniteMagnitude / 1024 else {
                    throw StorageFailure.message("These values exceed the chart's supported scale.")
                }
                return ChartDatum(id: point.id, date: point.date, value: value)
            }
        }
    }
}
