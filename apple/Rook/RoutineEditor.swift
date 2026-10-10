import SwiftUI
import RookKit

private struct ExerciseForm: Identifiable {
    let id = UUID()
    var storedID: String?
    var name = ""
    var sets = 3
    var reps = "8"
    var weight = "0"
    var rest = 90
    var originalWeightKg: Double?
    var initialWeight = "0"
}

struct RoutineEditor: View {
    @EnvironmentObject private var model: RookModel
    @Environment(\.dismiss) private var dismiss
    let routine: Routine?
    let unit: WeightUnit
    @State private var name: String
    @State private var exercises: [ExerciseForm]
    @State private var saveError: String?

    init(routine: Routine?, unit: WeightUnit) {
        self.routine = routine
        self.unit = unit
        _name = State(initialValue: routine?.name ?? "")
        _exercises = State(initialValue: routine?.exercises.map { plan in
            let weight = RookNumber.weight(plan.weightKg, unit: unit)
            return ExerciseForm(
                storedID: plan.id, name: plan.name, sets: Int(plan.sets),
                reps: String(plan.reps), weight: weight, rest: Int(plan.restSeconds),
                originalWeightKg: plan.weightKg, initialWeight: weight
            )
        } ?? [ExerciseForm()])
    }

    var body: some View {
        Form {
            Section("Routine") {
                TextField("Routine name", text: $name)
                    .textInputAutocapitalization(.sentences)
                    .accessibilityIdentifier("routine-name")
            }.listRowBackground(RookColor.surface)
            ForEach($exercises) { $exercise in
                Section {
                    TextField("Exercise name", text: $exercise.name)
                        .textInputAutocapitalization(.sentences)
                    Stepper("Sets: \(exercise.sets)", value: $exercise.sets, in: 1...100)
                    HStack {
                        Text("Target reps")
                        Spacer()
                        TextField("Reps", text: $exercise.reps)
                            .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                            .accessibilityLabel("Target repetitions for \(exercise.name)")
                    }
                    HStack {
                        Text("Starting weight (\(unit == .kg ? "kg" : "lb"))")
                        Spacer()
                        TextField("Weight", text: $exercise.weight)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                            .accessibilityLabel("Starting weight for \(exercise.name)")
                    }
                    Stepper(
                        "Rest: \(exercise.rest) sec", value: $exercise.rest, in: 0...3600, step: 15
                    )
                    if exercises.count > 1 {
                        Button("Remove exercise", role: .destructive) {
                            exercises.removeAll { $0.id == exercise.id }
                        }
                    }
                } header: {
                    Text(exercise.name.isEmpty ? "Exercise" : exercise.name)
                } footer: {
                    Text("Zero weight can represent bodyweight or no added load. Previous completed sets will be prefilled when you return.")
                }
                .listRowBackground(RookColor.surface)
            }
            Section {
                Button("Add exercise", systemImage: "plus") { exercises.append(ExerciseForm()) }
                    .disabled(exercises.count >= 50)
            }.listRowBackground(RookColor.surface)
        }
        .rookList().navigationTitle(routine == nil ? "New routine" : "Edit routine")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }.disabled(model.busy)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save() } }
                    .disabled(model.busy).accessibilityIdentifier("save-routine")
            }
        }
        .interactiveDismissDisabled(model.busy)
        .alert("Routine not saved", isPresented: Binding(
            get: { saveError != nil }, set: { if !$0 { saveError = nil } }
        )) { Button("OK") { saveError = nil } } message: { Text(saveError ?? "") }
    }

    private func save() async {
        do {
            let drafts = try exercises.map { exercise -> ExerciseDraft in
                let weight: Double
                if exercise.weight == exercise.initialWeight, let original = exercise.originalWeightKg {
                    weight = original
                } else {
                    weight = try canonicalWeight(weight: RookNumber.parse(exercise.weight), unit: unit)
                }
                return ExerciseDraft(
                    id: exercise.storedID, name: exercise.name,
                    sets: UInt32(exercise.sets), reps: try RookNumber.reps(exercise.reps),
                    weightKg: weight, restSeconds: UInt32(exercise.rest)
                )
            }
            if await model.perform(.saveRoutine(routine?.id, name, drafts)) { dismiss() }
        } catch { saveError = error.localizedDescription }
    }
}
