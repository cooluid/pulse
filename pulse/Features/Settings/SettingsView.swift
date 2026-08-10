import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var model: PulseAppModel
    @Environment(\.openURL) private var openURL
    @State private var showsResetConfirmation = false
    @State private var showsExporter = false
    @State private var exportDocument: PulseExportDocument?
    @State private var showsImporter = false
    @State private var pendingImport: PulseExportPayload?

    var body: some View {
        Form {
            reminderSection
            experienceSection
            dataSection
            aboutSection
        }
        .tint(PulseDesign.tint)
        .navigationTitle("settings.navigation_title")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "settings.reset_confirmation.title",
            isPresented: $showsResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("settings.reset_confirmation.action", role: .destructive) {
                Task { await model.resetAllData() }
            }
            Button("action.cancel", role: .cancel) {}
        } message: {
            Text("settings.reset_confirmation.message")
        }
        .fileExporter(
            isPresented: $showsExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportFilename
        ) { result in
            if case .failure(let error) = result {
                model.errorMessage = error.localizedDescription
            }
            exportDocument = nil
        }
        .fileImporter(
            isPresented: $showsImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let url = try result.get().first else { return }
                pendingImport = try model.decodeImport(from: url)
            } catch {
                model.errorMessage = error.localizedDescription
            }
        }
        .confirmationDialog(
            "settings.import_confirmation.title",
            isPresented: Binding(
                get: { pendingImport != nil },
                set: { if !$0 { pendingImport = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let pendingImport {
                Button("settings.import_confirmation.action", role: .destructive) {
                    Task {
                        await model.importData(pendingImport)
                        self.pendingImport = nil
                    }
                }
            }
            Button("action.cancel", role: .cancel) {
                pendingImport = nil
            }
        } message: {
            Text(
                String(
                    format: String(localized: "settings.import_confirmation.message"),
                    pendingImport?.records.count ?? 0
                )
            )
        }
    }

    private var reminderSection: some View {
        Section {
            Toggle(
                "settings.reminder.toggle",
                isOn: Binding(
                    get: { model.settings.reminderEnabled },
                    set: { enabled in
                        Task { await model.setReminderEnabled(enabled) }
                    }
                )
            )

            if model.settings.reminderEnabled {
                DatePicker(
                    "settings.reminder.time",
                    selection: reminderTimeBinding,
                    displayedComponents: .hourAndMinute
                )
                .environment(\.timeZone, TimeZone.gmt)
            }

            if model.notificationPermission == .denied {
                Button("settings.notification.open_system_settings") {
                    guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
                    openURL(url)
                }
            }
        } header: {
            Text("settings.reminder.section")
        } footer: {
            Text("settings.reminder.footer")
        }
    }

    private var experienceSection: some View {
        Section("settings.experience.section") {
            Toggle(
                "settings.haptics",
                isOn: Binding(
                    get: { model.settings.hapticsEnabled },
                    set: { model.settings.hapticsEnabled = $0 }
                )
            )

            Picker(
                "settings.week_start",
                selection: Binding(
                    get: { model.settings.weekStart },
                    set: { model.settings.weekStart = $0 }
                )
            ) {
                ForEach(WeekStart.allCases) { start in
                    Text(start.localizedName).tag(start)
                }
            }

            NavigationLink {
                TimeZonePickerView(model: model)
            } label: {
                LabeledContent("settings.timezone") {
                    Text(model.habit?.timeZoneIdentifier ?? "")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var dataSection: some View {
        Section {
            Button {
                do {
                    exportDocument = try model.makeExportDocument()
                    showsExporter = true
                } catch {
                    model.errorMessage = error.localizedDescription
                }
            } label: {
                Label("settings.export", systemImage: "square.and.arrow.up")
            }

            Button {
                showsImporter = true
            } label: {
                Label("settings.import", systemImage: "square.and.arrow.down")
            }

            Button(role: .destructive) {
                showsResetConfirmation = true
            } label: {
                Label("settings.reset", systemImage: "trash")
            }
        } header: {
            Text("settings.data.section")
        } footer: {
            Text("settings.data.footer")
        }
    }

    private var aboutSection: some View {
        Section("settings.about.section") {
            LabeledContent("settings.version", value: appVersion)
            LabeledContent("settings.storage", value: String(localized: "settings.storage.local"))
        }
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: { model.settings.reminderTime.pickerDate },
            set: { date in
                guard let reminderTime = ReminderTime(pickerDate: date) else {
                    model.errorMessage = String(localized: "error.settings")
                    return
                }
                Task { await model.updateReminderTime(reminderTime) }
            }
        )
    }

    private var exportFilename: String {
        let day = model.today?.storageValue ?? "export"
        return "pulse-\(day)"
    }

    private var appVersion: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return [shortVersion, buildVersion.map { "(\($0))" }]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}

private struct TimeZonePickerView: View {
    @Bindable var model: PulseAppModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var pendingIdentifier: String?

    var body: some View {
        List(filteredIdentifiers, id: \.self) { identifier in
            Button {
                guard identifier != model.habit?.timeZoneIdentifier else { return }
                pendingIdentifier = identifier
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(displayName(identifier))
                            .foregroundStyle(.primary)
                        Text(identifier)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if identifier == model.habit?.timeZoneIdentifier {
                        Image(systemName: "checkmark")
                            .foregroundStyle(PulseDesign.primary)
                    }
                }
            }
        }
        .tint(PulseDesign.tint)
        .navigationTitle("settings.timezone")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "settings.timezone.search")
        .confirmationDialog(
            "settings.timezone_confirmation.title",
            isPresented: Binding(
                get: { pendingIdentifier != nil },
                set: { if !$0 { pendingIdentifier = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let pendingIdentifier {
                Button("settings.timezone_confirmation.action") {
                    Task {
                        await model.updateTimeZone(identifier: pendingIdentifier)
                        dismiss()
                    }
                }
            }
            Button("action.cancel", role: .cancel) {
                pendingIdentifier = nil
            }
        } message: {
            Text("settings.timezone_confirmation.message")
        }
    }

    private var filteredIdentifiers: [String] {
        guard !searchText.isEmpty else { return TimeZone.knownTimeZoneIdentifiers }
        return TimeZone.knownTimeZoneIdentifiers.filter {
            $0.localizedCaseInsensitiveContains(searchText)
                || displayName($0).localizedCaseInsensitiveContains(searchText)
        }
    }

    private func displayName(_ identifier: String) -> String {
        guard let timeZone = TimeZone(identifier: identifier) else { return identifier }
        return timeZone.localizedName(for: .standard, locale: .autoupdatingCurrent) ?? identifier
    }
}
