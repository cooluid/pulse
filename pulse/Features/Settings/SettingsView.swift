import SwiftUI
import UniformTypeIdentifiers
import PulseCore

struct SettingsView: View {
    @Bindable var model: PulseAppModel
    @Environment(\.openURL) private var openURL
    @Environment(\.locale) private var locale
    @State private var showsResetConfirmation = false
    @State private var passphraseRequest: BackupPassphraseMode?
    @State private var showsExporter = false
    @State private var exportFile: PulseBackupExport?
    @State private var showsImporter = false
    @State private var selectedBackupURL: URL?
    @State private var pendingRestore: PulseDecodedBackup?

    var body: some View {
        Form {
            commitmentSection
            dailySection
            storeSection
            appearanceSection
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
        .sheet(item: $passphraseRequest, onDismiss: finishPassphraseRequest) { mode in
            BackupPassphraseView(mode: mode, locale: locale) { passphrase in
                switch mode {
                case .export:
                    exportFile = try await model.makeBackupExport(passphrase: passphrase)
                case .restore:
                    guard let selectedBackupURL else {
                        throw PulseCoreError.invalidBackup
                    }
                    pendingRestore = try await model.decodeBackup(
                        from: selectedBackupURL,
                        passphrase: passphrase
                    )
                }
            }
        }
        .fileExporter(
            isPresented: $showsExporter,
            item: exportFile,
            contentTypes: [.pulseBackup],
            defaultFilename: backupFilename
        ) { result in
            if case .failure(let error) = result {
                model.errorMessage = error.localizedDescription
            }
            exportFile = nil
        }
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

    private var appearanceSection: some View {
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
                ForEach(PulseInterfaceLanguage.allCases) { language in
                    Text(language.localizedName(locale: locale)).tag(language)
                }
            }
            .accessibilityIdentifier("settings.language.picker")
            .id("settings.language.\(locale.identifier)")

            NavigationLink {
                WidgetStyleGalleryView(model: model)
            } label: {
                LabeledContent("settings.widget.style") {
                    Text(model.settings.widgetStyle.localizedName(locale: locale))
                        .foregroundStyle(PulseDesign.secondary)
                }
            }
            .accessibilityIdentifier("settings.widget.gallery.link")
        }
    }

    private var dailySection: some View {
        Section {
            Toggle(
                isOn: Binding(
                    get: { model.displayedReminderEnabled },
                    set: { enabled in
                        model.requestReminderEnabled(enabled)
                    }
                )
            ) {
                Text("settings.reminder.toggle")
            }
            .accessibilityLabel("settings.reminder.toggle")
            .accessibilityIdentifier("settings.reminder.toggle")

            if model.displayedReminderEnabled {
                DatePicker(
                    "settings.reminder.time",
                    selection: reminderTimeBinding,
                    displayedComponents: .hourAndMinute
                )
                .environment(\.timeZone, TimeZone.gmt)

                if model.reminderSyncState == .syncing {
                    ProgressView("settings.reminder.syncing")
                        .accessibilityIdentifier("settings.reminder.syncing")
                } else {
                    Label(reminderDeliveryDescriptionKey, systemImage: reminderDeliveryIcon)
                        .font(.footnote)
                        .foregroundStyle(PulseDesign.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("settings.reminder.delivery")
                }

                if model.notificationPermission == .denied {
                    Button("settings.notification.open_system_settings") {
                        guard let url = URL(
                            string: UIApplication.openNotificationSettingsURLString
                        ) else { return }
                        openURL(url)
                    }
                }

                if model.reminderSyncState == .failed {
                    Label("settings.reminder.sync_failed", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(PulseDesign.action)
                }
            }

            Toggle(
                "settings.media.invitation",
                isOn: Binding(
                    get: { model.settings.mediaInvitationEnabled },
                    set: { model.settings.mediaInvitationEnabled = $0 }
                )
            )

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
        } header: {
            Text("settings.daily.section")
        }
    }

    private var storeSection: some View {
        Section("settings.store.section") {
            NavigationLink {
                EnhancementStoreView(model: model)
            } label: {
                HStack(spacing: PulseDesign.spacing12) {
                    PulseBrandMark(size: 44)
                    VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
                        Text("store.title")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(PulseDesign.ink)
                        Text(
                            model.featureAccess.hasEnhancement
                                ? "settings.store.unlocked"
                                : "settings.store.open"
                        )
                        .font(.footnote)
                        .foregroundStyle(
                            model.featureAccess.hasEnhancement
                                ? PulseDesign.grass
                                : PulseDesign.secondary
                        )
                    }
                }
                .padding(.vertical, PulseDesign.spacing8)
            }
            .accessibilityIdentifier("settings.store.link")
        }
    }

    private var reminderDeliveryDescriptionKey: LocalizedStringKey {
        switch model.reminderDeliveryMode {
        case .disabled:
            "settings.reminder.delivery.disabled"
        case .localNotification:
            "settings.reminder.delivery.notification"
        case .scheduledLiveActivity:
            "settings.reminder.delivery.live_activity"
        }
    }

    private var reminderDeliveryIcon: String {
        switch model.reminderDeliveryMode {
        case .disabled:
            "exclamationmark.triangle"
        case .localNotification:
            "bell.badge"
        case .scheduledLiveActivity:
            "waveform.path.ecg.rectangle"
        }
    }

    private var dataSection: some View {
        Section {
            exportButton
            importButton
            LabeledContent(
                "settings.media.storage",
                value: ByteCountFormatter.string(
                    fromByteCount: model.mediaStorageByteCount,
                    countStyle: .file
                )
            )
            resetButton

        } header: {
            Text("settings.data.section")
        }
    }

    private var exportButton: some View {
        Button {
            exportFile = nil
            passphraseRequest = .export
        } label: {
            Label("settings.backup.export", systemImage: "lock.doc")
        }
        .accessibilityIdentifier("settings.backup.export.button")
    }

    private var importButton: some View {
        Button {
            showsImporter = true
        } label: {
            Label("settings.backup.restore", systemImage: "lock.open")
        }
        .accessibilityIdentifier("settings.backup.restore.button")
        .fileImporter(
            isPresented: $showsImporter,
            allowedContentTypes: [.pulseBackup]
        ) { result in
            do {
                selectedBackupURL = try result.get()
                passphraseRequest = .restore
            } catch {
                model.errorMessage = error.localizedDescription
            }
        }
        .confirmationDialog(
            "settings.backup.restore_confirmation.title",
            isPresented: Binding(
                get: { pendingRestore != nil },
                set: { if !$0 { pendingRestore = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let pendingRestore {
                Button("settings.backup.restore_confirmation.action", role: .destructive) {
                    Task {
                        if await model.restoreBackup(pendingRestore) {
                            self.pendingRestore = nil
                        }
                    }
                }
                .accessibilityIdentifier("settings.backup.restore.confirm.button")
            }
            Button("action.cancel", role: .cancel) {
                pendingRestore = nil
            }
        } message: {
            Text(
                String(
                    format: PulseLocalization.string(
                        "settings.backup.restore_confirmation.message",
                        locale: locale
                    ),
                    pendingRestore?.payload.records.count ?? 0,
                    pendingRestore?.payload.media.count ?? 0
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

    private var backupFilename: String {
        PulseBackupContract.filename(day: model.today?.storageValue)
    }

    private func finishPassphraseRequest() {
        selectedBackupURL = nil
        if exportFile != nil {
            showsExporter = true
        }
    }

    private var appVersion: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return [shortVersion, buildVersion.map { "(\($0))" }]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}

private enum BackupPassphraseMode: Identifiable {
    case export
    case restore

    var id: Self { self }

    var titleKey: String {
        switch self {
        case .export: "backup.passphrase.export.title"
        case .restore: "backup.passphrase.restore.title"
        }
    }

    var messageKey: String {
        switch self {
        case .export: "backup.passphrase.export.message"
        case .restore: "backup.passphrase.restore.message"
        }
    }

    var actionKey: String {
        switch self {
        case .export: "backup.passphrase.export.action"
        case .restore: "backup.passphrase.restore.action"
        }
    }

    var requiresConfirmation: Bool { self == .export }
}

private struct BackupPassphraseView: View {
    let mode: BackupPassphraseMode
    let locale: Locale
    let onSubmit: @MainActor (String) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @State private var passphrase = ""
    @State private var confirmation = ""
    @State private var errorMessage: String?
    @State private var isProcessing = false
    @State private var showsProgress = false

    private enum Field {
        case passphrase
        case confirmation
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(PulseLocalization.string(mode.messageKey, locale: locale))
                        .font(.footnote)
                        .foregroundStyle(PulseDesign.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    passphraseField(
                        labelKey: "backup.passphrase.field",
                        text: $passphrase,
                        field: .passphrase
                    )

                    if mode.requiresConfirmation {
                        passphraseField(
                            labelKey: "backup.passphrase.confirmation",
                            text: $confirmation,
                            field: .confirmation
                        )
                    }
                }

                if showsProgress {
                    Section {
                        ProgressView(
                            PulseLocalization.string(
                                "backup.passphrase.processing",
                                locale: locale
                            )
                        )
                    }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(PulseDesign.action)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("backup.passphrase.error")
                    }
                }
            }
            .navigationTitle(PulseLocalization.string(mode.titleKey, locale: locale))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") {
                        clearSensitiveState()
                        dismiss()
                    }
                    .disabled(isProcessing)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(PulseLocalization.string(mode.actionKey, locale: locale)) {
                        submit()
                    }
                    .disabled(
                        isProcessing
                            || passphrase.isEmpty
                            || (mode.requiresConfirmation && confirmation.isEmpty)
                    )
                    .accessibilityIdentifier("backup.passphrase.submit")
                }
            }
            .onAppear { focusedField = .passphrase }
            .onDisappear { clearSensitiveState() }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(isProcessing)
    }

    private func submit() {
        errorMessage = nil
        guard !mode.requiresConfirmation || passphrase == confirmation else {
            errorMessage = PulseLocalization.string(
                "error.backup_passphrase_mismatch",
                locale: locale
            )
            clearSensitiveState()
            focusedField = .passphrase
            return
        }
        let submittedPassphrase = passphrase
        clearSensitiveState()
        focusedField = nil
        isProcessing = true
        Task {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(PulseDesign.savingIndicatorDelay))
                if isProcessing {
                    showsProgress = true
                }
            }
            do {
                try await onSubmit(submittedPassphrase)
                isProcessing = false
                showsProgress = false
                dismiss()
            } catch {
                isProcessing = false
                showsProgress = false
                errorMessage = PulseErrorPresentation.localizedMessage(for: error, locale: locale)
                    ?? PulseLocalization.string("error.generic", locale: locale)
                focusedField = .passphrase
            }
        }
    }

    private func passphraseField(
        labelKey: String,
        text: Binding<String>,
        field: Field
    ) -> some View {
        let label = PulseLocalization.string(labelKey, locale: locale)
        return VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(PulseDesign.secondary)
                .accessibilityHidden(true)
            SecureField(label, text: text)
                .focused($focusedField, equals: field)
                .textContentType(field == .confirmation || mode == .export ? .newPassword : .password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .privacySensitive()
                .accessibilityLabel(label)
                .accessibilityIdentifier(
                    field == .passphrase
                        ? "backup.passphrase.field"
                        : "backup.passphrase.confirmation"
                )
        }
    }

    private func clearSensitiveState() {
        passphrase.removeAll(keepingCapacity: false)
        confirmation.removeAll(keepingCapacity: false)
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
