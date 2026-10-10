import SwiftUI
import RookKit

struct ActiveWorkoutView: View {
    @EnvironmentObject private var model: RookModel
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var discard = false

    var body: some View {
        Group {
            if let workout = model.snapshot?.active {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(workout.routineName).font(.title.bold())
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                HStack {
                                    Text("\(RookNumber.clock(context.date.timeIntervalSince(RookNumber.date(workout.startedMs)))) elapsed")
                                    Spacer()
                                    Text("\(workout.completedSets) / \(workout.exercises.reduce(0) { $0 + $1.sets.count }) sets")
                                }
                                .font(.subheadline.monospacedDigit()).foregroundStyle(RookColor.secondary)
                            }
                            HStack(spacing: 6) {
                                ForEach(workout.exercises, id: \.id) { exercise in
                                    let completed = exercise.sets.filter(\.completed).count
                                    ProgressView(value: Double(completed), total: Double(exercise.sets.count))
                                        .tint(RookColor.accent)
                                        .accessibilityLabel("\(exercise.name): \(completed) of \(exercise.sets.count) sets complete")
                                }
                            }
                        }.padding(.vertical, 6)
                    }.listRowBackground(RookColor.surface)
                    if let end = workout.restEndMs {
                        Section {
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                let remaining = RookNumber.date(end).timeIntervalSince(context.date)
                                ViewThatFits(in: .horizontal) {
                                    HStack {
                                        restText(remaining)
                                        Spacer()
                                        restButtons
                                    }
                                    VStack(alignment: .leading, spacing: 12) {
                                        restText(remaining)
                                        restButtons
                                    }
                                }.padding(.vertical, 4)
                            }
                        }.listRowBackground(RookColor.surface)
                    }
                    ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { position, exercise in
                        Section {
                            if !typeSize.isAccessibilitySize {
                                HStack {
                                    Text("Set").frame(width: 26, alignment: .leading)
                                    Text("Previous").frame(maxWidth: .infinity, alignment: .leading)
                                    Text(model.unitLabel).frame(width: 68)
                                    Text("Reps").frame(width: 58)
                                    Spacer().frame(width: 46)
                                }.font(.caption).foregroundStyle(RookColor.secondary)
                            }
                            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                                SetRow(
                                    set: set, exercise: exercise, index: index,
                                    previous: previous(for: exercise, index: index),
                                    position: position
                                )
                            }
                            .onDelete { indices in
                                Task {
                                    for index in indices {
                                        _ = await model.perform(.removeSet(exercise.sets[index].id))
                                    }
                                }
                            }
                            Button("Add set", systemImage: "plus") {
                                Task { _ = await model.perform(.addSet(exercise.id)) }
                            }.frame(minHeight: 44)
                        } header: {
                            Text(exercise.name).font(.headline).textCase(nil)
                        } footer: {
                            Text("Rest \(exercise.restSeconds) sec · Changes save when valid. Complete a set to start rest.")
                                .foregroundStyle(RookColor.secondary)
                        }
                        .listRowBackground(RookColor.surface)
                    }
                    Section {
                        Button("Discard workout", role: .destructive) { discard = true }
                    }.listRowBackground(RookColor.surface)
                }
                .rookList()
            } else {
                ContentUnavailableView("No active workout", systemImage: "figure.strengthtraining.traditional")
            }
        }
        .navigationTitle("Workout").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { Task { await model.closeWorkout() } }.disabled(model.busy)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Finish") { Task { _ = await model.perform(.finish) } }
                    .disabled(model.busy).accessibilityIdentifier("finish-workout")
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
        .disabled(model.busy)
        .interactiveDismissDisabled()
        .alert("Discard this workout?", isPresented: $discard) {
            Button("Keep workout", role: .cancel) {}
            Button("Discard", role: .destructive) { Task { _ = await model.perform(.discard) } }
        } message: {
            Text("The active session and its sets will be removed. Your routines and completed history will stay.")
        }
    }

    private func restText(_ seconds: TimeInterval) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(seconds > 0 ? "Rest" : "Rest finished").font(.subheadline).foregroundStyle(RookColor.secondary)
            Text(RookNumber.clock(seconds)).font(.title.bold().monospacedDigit())
                .accessibilityIdentifier("rest-clock")
        }
    }

    private var restButtons: some View {
        HStack {
            Button("+30 sec") { Task { _ = await model.perform(.adjustRest(30)) } }
                .buttonStyle(.bordered).frame(minHeight: 44)
            Button("Skip") { Task { _ = await model.perform(.skipRest) } }
                .buttonStyle(.bordered).frame(minHeight: 44)
        }
    }

    private func previous(for exercise: WorkoutExercise, index: Int) -> WorkoutSet? {
        for workout in model.snapshot?.history ?? [] {
            if let earlier = workout.exercises.first(where: { $0.templateId == exercise.templateId }),
               earlier.sets.indices.contains(index), earlier.sets[index].completed {
                return earlier.sets[index]
            }
        }
        return nil
    }
}

private struct SetRow: View {
    @EnvironmentObject private var model: RookModel
    @Environment(\.dynamicTypeSize) private var typeSize
    let set: WorkoutSet
    let exercise: WorkoutExercise
    let index: Int
    let previous: WorkoutSet?
    let position: Int
    @State private var weight = ""
    @State private var reps = ""
    @State private var initialized = false
    @FocusState private var focused: Field?
    private enum Field { case weight, reps }

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Text("Set \(index + 1)").font(.headline); Spacer(); completeButton }
                    Text("Previous: \(previousLabel)").foregroundStyle(RookColor.secondary)
                    HStack { Text("Weight (\(model.unitLabel))"); weightField }
                    HStack { Text("Reps"); repsField }
                }.padding(.vertical, 5)
            } else {
                HStack(spacing: 8) {
                    Text("\(index + 1)").font(.body.bold()).frame(width: 26, alignment: .leading)
                    Text(previousLabel).font(.caption.monospacedDigit())
                        .foregroundStyle(RookColor.secondary).frame(maxWidth: .infinity, alignment: .leading)
                    weightField.frame(width: 68)
                    repsField.frame(width: 58)
                    completeButton.frame(width: 44)
                }.padding(.vertical, 3)
            }
        }
        .onAppear {
            let text = model.text(for: set)
            weight = text.weight
            reps = text.reps
            initialized = true
        }
        .onChange(of: focused) { old, new in
            if old != nil, new == nil { Task { do { try await model.flushEdits() } catch { model.report(error) } } }
        }
        .onChange(of: set.weightKg) { _, _ in
            if focused == nil, model.edits[set.id] == nil { weight = RookNumber.editWeight(set.weightKg, unit: model.unit) }
        }
    }

    private var previousLabel: String {
        guard let previous else { return "—" }
        return "\(RookNumber.weight(previous.weightKg, unit: model.unit)) × \(previous.reps)"
    }

    private var weightField: some View {
        TextField(model.unitLabel, text: Binding(
            get: { weight },
            set: { weight = $0; queue() }
        ))
            .keyboardType(.decimalPad).focused($focused, equals: .weight)
            .textFieldStyle(.roundedBorder).multilineTextAlignment(.center)
            .font(.body.monospacedDigit()).frame(minHeight: 44)
            .accessibilityLabel("Weight in \(model.unitLabel), \(exercise.name), set \(index + 1)")
            .accessibilityIdentifier("weight-\(position)-\(index)")
    }

    private var repsField: some View {
        TextField("Reps", text: Binding(
            get: { reps },
            set: { reps = $0; queue() }
        ))
            .keyboardType(.numberPad).focused($focused, equals: .reps)
            .textFieldStyle(.roundedBorder).multilineTextAlignment(.center)
            .font(.body.monospacedDigit()).frame(minHeight: 44)
            .accessibilityLabel("Repetitions, \(exercise.name), set \(index + 1)")
            .accessibilityIdentifier("reps-\(position)-\(index)")
    }

    private var completeButton: some View {
        Button {
            focused = nil
            Task {
                await model.commitSet(id: set.id, completed: !set.completed)
            }
        } label: {
            Image(systemName: set.completed ? "checkmark" : "circle")
                .frame(minWidth: 24, minHeight: 28)
        }
        .buttonStyle(.borderedProminent)
        .tint(set.completed ? RookColor.accent : RookColor.track)
        .foregroundStyle(set.completed ? RookColor.onAccent : Color.primary)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel("\(set.completed ? "Unmark" : "Complete") \(exercise.name), set \(index + 1)")
        .accessibilityValue(set.completed ? "Completed" : "Not completed")
        .accessibilityIdentifier("complete-\(position)-\(index)")
    }

    private func queue() {
        guard initialized else { return }
        model.queueEdit(SetEdit(id: set.id, weight: weight, reps: reps, unit: model.unit))
    }
}
