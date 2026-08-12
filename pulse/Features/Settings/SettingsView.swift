import SwiftUI
import UniformTypeIdentifiers
import PulseCore

struct SettingsView: View {
    @Bindable var model: PulseAppModel
    @Environment(\.openURL) private var openURL
    @Environment(\.locale) private var locale
    @State private var showsResetConfirmation = false
    @State private var showsExporter = false
    @State private var exportDocument: PulseExportDocument?
    @State private var showsImporter = false
    @State private var pendingImport: PulseExportPayload?

    var body: some View {
        Form {
            commitmentSection
            reminderSection
            personalizationSection
            widgetSection
            experienceSection
            dataSection
            aboutSection
        }
        .scrollContentBackground(.hidden)
        .background(PulseDesign.background)
        .foregroundStyle(PulseDesign.ink)
        .tint(PulseDesign.tint)
        .navigationTitle(
            PulseLocalization.string("settings.navigation_title", locale: locale)
        )
        .navigationBarTitleDisplayMode(.inline)
        .pulseSecondaryNavigation()
        .disabled(model.operation != nil)
    }

    private var commitmentSection: some View {
        Section("commitment.section") {
            NavigationLink {
                CommitmentIdentityEditor(model: model, mode: .settings)
            } label: {
                VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
                    Text(model.habit?.name ?? "")
                        .foregroundStyle(PulseDesign.ink)
                    Text(model.habit?.purpose ?? PulseLocalization.string(
                        "commitment.purpose.not_set",
                        locale: locale
                    ))
                    .font(.footnote)
                    .foregroundStyle(PulseDesign.secondary)
                    .lineLimit(2)
                }
            }
            .accessibilityIdentifier("settings.commitment.link")
        }
    }

    private var personalizationSection: some View {
        Section("settings.personalization.section") {
            Picker(
                "settings.theme",
                selection: Binding(
                    get: { model.settings.theme },
                    set: { model.settings.theme = $0 }
                )
            ) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.localizedName(locale: locale)).tag(theme)
                }
            }
            .accessibilityIdentifier("settings.theme.picker")
            .id("settings.theme.\(locale.identifier)")

            Picker(
                "settings.language",
                selection: Binding(
                    get: { model.settings.language },
                    set: { model.requestLanguage($0) }
                )
            ) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.localizedName(locale: locale)).tag(language)
                }
            }
            .accessibilityIdentifier("settings.language.picker")
            .id("settings.language.\(locale.identifier)")
        }
    }

    private var reminderSection: some View {
        Section {
            Toggle(
                isOn: Binding(
                    get: { model.displayedReminderEnabled },
                    set: { enabled in
                        model.requestReminderEnabled(enabled)
                    }
                )
            ) {
                VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
                    Text("settings.reminder.toggle")
                    Text("settings.reminder.footer")
                        .font(.footnote)
                        .foregroundStyle(PulseDesign.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityLabel("settings.reminder.toggle")
            .accessibilityHint("settings.reminder.footer")

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

            if model.reminderSyncState == .failed {
                Label("settings.reminder.sync_failed", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(PulseDesign.action)
            }
        } header: {
            Text("settings.reminder.section")
        }
    }

    private var widgetSection: some View {
        Section {
            Picker(
                "settings.widget.style",
                selection: Binding(
                    get: { model.settings.widgetStyle },
                    set: { model.requestWidgetStyle($0) }
                )
            ) {
                ForEach(PulseWidgetStyle.allCases) { style in
                    Text(style.localizedName(locale: locale)).tag(style)
                }
            }
            .accessibilityIdentifier("settings.widget.style.picker")
            .id("settings.widget.style.\(locale.identifier)")

            Label {
                Text("settings.widget.footer")
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "square.grid.2x2")
            }
            .font(.footnote)
            .foregroundStyle(PulseDesign.secondary)
            .accessibilityIdentifier("settings.widget.style.note")
        } header: {
            Text("settings.widget.section")
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
                    Text(start.localizedName(locale: locale)).tag(start)
                }
            }
            .id("settings.week-start.\(locale.identifier)")

            NavigationLink {
                TimeZonePickerView(model: model)
            } label: {
                LabeledContent("settings.timezone") {
                    Text(model.habit?.timeZoneIdentifier ?? "")
                        .foregroundStyle(PulseDesign.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var dataSection: some View {
        Section {
            exportButton
            importButton
            resetButton

            Label {
                Text("settings.data.footer")
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "externaldrive")
            }
            .font(.footnote)
            .foregroundStyle(PulseDesign.secondary)
            .accessibilityIdentifier("settings.data.note")
        } header: {
            Text("settings.data.section")
        }
    }

    private var exportButton: some View {
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
        .accessibilityIdentifier("settings.export.button")
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
    }

    private var importButton: some View {
        Button {
            showsImporter = true
        } label: {
            Label("settings.import", systemImage: "square.and.arrow.down")
        }
        .accessibilityIdentifier("settings.import.button")
        .fileImporter(
            isPresented: $showsImporter,
            allowedContentTypes: PulseExportDocument.readableContentTypes
        ) { result in
            do {
                pendingImport = try model.decodeImport(from: result.get())
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
                        if await model.importData(pendingImport) {
                            self.pendingImport = nil
                        }
                    }
                }
                .accessibilityIdentifier("settings.import.confirm.button")
            }
            Button("action.cancel", role: .cancel) {
                pendingImport = nil
            }
        } message: {
            Text(
                String(
                    format: PulseLocalization.string(
                        "settings.import_confirmation.message",
                        locale: locale
                    ),
                    pendingImport?.records.count ?? 0
                )
            )
        }
    }

    private var resetButton: some View {
        Button(role: .destructive) {
            showsResetConfirmation = true
        } label: {
            Label("settings.reset", systemImage: "trash")
        }
        .accessibilityIdentifier("settings.reset.button")
        .confirmationDialog(
            "settings.reset_confirmation.title",
            isPresented: $showsResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("settings.reset_confirmation.action", role: .destructive) {
                Task { _ = await model.resetAllData() }
            }
            .accessibilityIdentifier("settings.reset.confirm.button")
            Button("action.cancel", role: .cancel) {}
        } message: {
            Text("settings.reset_confirmation.message")
        }
    }

    private var aboutSection: some View {
        Section("settings.about.section") {
            LabeledContent("settings.version", value: appVersion)
            LabeledContent(
                "settings.storage",
                value: PulseLocalization.string("settings.storage.local", locale: locale)
            )
            Link(destination: PulseExternalLinks.privacyPolicy) {
                Label("settings.privacy_policy", systemImage: "hand.raised")
            }
            .accessibilityIdentifier("settings.privacy_policy.link")

            Link(destination: PulseExternalLinks.support) {
                Label("settings.support", systemImage: "questionmark.circle")
            }
            .accessibilityIdentifier("settings.support.link")
        }
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: { model.settings.reminderTime.pickerDate },
            set: { date in
                guard let reminderTime = ReminderTime(pickerDate: date) else {
                    model.errorMessage = PulseLocalization.string("error.settings", locale: locale)
                    return
                }
                model.requestReminderTime(reminderTime)
            }
        )
    }

    private var exportFilename: String {
        PulseDataContract.exportFilename(day: model.today?.storageValue)
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
    @Environment(\.locale) private var locale
    @State private var searchText = ""
    @State private var pendingIdentifier: String?

    var body: some View {
        List(filteredIdentifiers, id: \.self) { identifier in
            Button {
                guard identifier != model.habit?.timeZoneIdentifier else { return }
                pendingIdentifier = identifier
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
                        Text(displayName(identifier))
                            .foregroundStyle(PulseDesign.ink)
                        Text(identifier)
                            .font(.caption)
                            .foregroundStyle(PulseDesign.secondary)
                    }
                    Spacer()
                    if identifier == model.habit?.timeZoneIdentifier {
                        Image(systemName: "checkmark")
                            .foregroundStyle(PulseDesign.action)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(PulseDesign.background)
        .tint(PulseDesign.tint)
        .navigationTitle("settings.timezone")
        .navigationBarTitleDisplayMode(.inline)
        .pulseSecondaryNavigation()
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
                        if await model.updateTimeZone(identifier: pendingIdentifier) {
                            dismiss()
                        }
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
        return timeZone.localizedName(for: .standard, locale: locale) ?? identifier
    }
}
