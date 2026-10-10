import SwiftUI
import UniformTypeIdentifiers
import RookKit

private struct EncryptedBackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.data]
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw StorageFailure.message("The backup is not a regular file.")
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct SettingsView: View {
    @EnvironmentObject private var model: RookModel

    var body: some View {
        Form {
            Section {
                Picker("Weight unit", selection: Binding(
                    get: { model.unit },
                    set: { value in Task { _ = await model.perform(.settings(value, model.snapshot?.restAlerts == true)) } }
                )) {
                    Text("Kilograms").tag(WeightUnit.kg)
                    Text("Pounds").tag(WeightUnit.lb)
                }
                Toggle("Rest alerts", isOn: Binding(
                    get: { model.snapshot?.restAlerts == true },
                    set: { value in Task { await model.changeAlerts(value) } }
                ))
            } header: {
                Text("Training")
            } footer: {
                Text("Rest deadlines are saved. Optional notifications use a generic message when Rook is in the background.")
            }
            .listRowBackground(RookColor.surface)
            Section {
                NavigationLink("Create encrypted backup") { ExportBackupView() }
                Button("Restore encrypted backup") { model.showsImport = true }
            } header: {
                Text("Your data")
            } footer: {
                Text("The database key stays in this device's Keychain. Keep a portable backup and its passphrase somewhere safe; ordinary device backup is not the recovery method.")
            }
            .listRowBackground(RookColor.surface)
            Section("Storage") {
                LabeledContent("Database", value: "SQLCipher")
                LabeledContent("Backup", value: "age · passphrase")
                LabeledContent("Account", value: "Not required")
                Text("Your working database is encrypted and excluded from ordinary iCloud Backup. Losing the device and all backups/passphrases means losing the data.")
                    .font(.footnote).foregroundStyle(RookColor.secondary)
            }.listRowBackground(RookColor.surface)
            Section {
                Text("Rook · Prototype 0.1")
                Text("Eternal rookies. Always learning.")
                    .foregroundStyle(RookColor.secondary)
                Text("Not independently security-audited. Back up before updating this prototype.")
                    .font(.footnote).foregroundStyle(RookColor.secondary)
            }.listRowBackground(RookColor.surface)
        }
        .rookList().navigationTitle("Settings")
        .disabled(model.busy)
    }
}

struct ExportBackupView: View {
    @EnvironmentObject private var model: RookModel
    @State private var passphrase = ""
    @State private var confirmation = ""
    @State private var document: EncryptedBackupDocument?
    @State private var exporting = false
    @State private var error: String?

    var body: some View {
        Form {
            Section {
                SecureField("Backup passphrase", text: $passphrase)
                    .textContentType(.newPassword)
                SecureField("Repeat passphrase", text: $confirmation)
                    .textContentType(.newPassword)
            } header: {
                Text("A key you can take with you")
            } footer: {
                Text("Use at least 12 characters, preferably several random words. This passphrase protects the backup, not your normal app access. Rook cannot reset it.")
            }.listRowBackground(RookColor.surface)
            Section {
                Button {
                    Task { await createBackup() }
                } label: {
                    HStack {
                        Text(model.busy ? "Encrypting backup…" : "Encrypt and save")
                        Spacer()
                        if model.busy { ProgressView() }
                    }
                }.frame(minHeight: 44)
            }.listRowBackground(RookColor.surface)
            Section {
                Text("Includes routines, settings, completed workouts, and any active workout. Only encrypted bytes are written to the exported file.")
                    .foregroundStyle(RookColor.secondary)
            }.listRowBackground(Color.clear)
        }
        .rookList().navigationTitle("Encrypted backup").navigationBarTitleDisplayMode(.inline)
        .disabled(model.busy)
        .fileExporter(
            isPresented: $exporting, document: document, contentType: .data,
            defaultFilename: "Rook-\(Date().formatted(.iso8601.year().month().day().dateSeparator(.dash))).rook.age"
        ) { result in
            switch result {
            case .success:
                model.issue = RookIssue(title: "Backup saved", message: "Keep this encrypted file and its passphrase available outside this phone.")
            case .failure(let error):
                model.report(error)
            }
            document = nil
        }
        .alert("Backup not created", isPresented: Binding(
            get: { error != nil }, set: { if !$0 { error = nil } }
        )) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }

    private func createBackup() async {
        guard passphrase == confirmation else { error = "The passphrases do not match."; return }
        if let data = await model.export(passphrase: passphrase) {
            document = EncryptedBackupDocument(data: data)
            passphrase = ""
            confirmation = ""
            exporting = true
        }
    }
}

struct RestoreBackupView: View {
    @EnvironmentObject private var model: RookModel
    @Environment(\.dismiss) private var dismiss
    let url: URL
    @State private var passphrase = ""
    @State private var confirm = false

    var body: some View {
        Form {
            Section("Selected backup") {
                Text(url.lastPathComponent).font(.body).textSelection(.enabled)
            }.listRowBackground(RookColor.surface)
            Section {
                SecureField("Backup passphrase", text: $passphrase).textContentType(.password)
            } footer: {
                Text("The backup is checked before any data is replaced. The original phone's device key is not needed.")
            }.listRowBackground(RookColor.surface)
            Section {
                Button {
                    confirm = true
                } label: {
                    HStack {
                        Text(model.busy ? "Restoring…" : "Restore this backup")
                        Spacer()
                        if model.busy { ProgressView() }
                    }
                }.frame(minHeight: 44)
            }.listRowBackground(RookColor.surface)
        }
        .rookList().navigationTitle("Restore backup").navigationBarTitleDisplayMode(.inline)
        .disabled(model.busy)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(model.busy) }
        }
        .interactiveDismissDisabled(model.busy)
        .confirmationDialog("Replace your current data?", isPresented: $confirm, titleVisibility: .visible) {
            Button("Replace and restore", role: .destructive) {
                Task {
                    if await model.restore(url: url, passphrase: passphrase) {
                        passphrase = ""
                        dismiss()
                        model.issue = RookIssue(title: "Backup restored", message: "Routines and workouts are now stored using this device's key.")
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This replaces all routines, history, settings, and any active workout with the backup. Export your current data first if you want to keep it.")
        }
    }
}
