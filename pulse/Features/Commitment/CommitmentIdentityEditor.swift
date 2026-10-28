import SwiftUI
import PulseCore

enum CommitmentIdentityEditorMode {
    case onboarding
    case settings
}

struct CommitmentIdentityEditor: View {
    private enum Field: Hashable {
        case name
        case purpose
    }

    @Bindable var model: PulseAppModel
    let mode: CommitmentIdentityEditorMode

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.pulseVisualTheme) private var visualTheme
    @State private var name: String
    @State private var purpose: String
    @FocusState private var focusedField: Field?

    init(model: PulseAppModel, mode: CommitmentIdentityEditorMode) {
        self.model = model
        self.mode = mode
        _name = State(initialValue: model.habit?.name ?? "")
        _purpose = State(initialValue: model.habit?.purpose ?? "")
    }

    var body: some View {
        Form {
            if mode == .onboarding {
                onboardingIntroduction
            }

            identityFields
                .pulseFormRows(for: visualTheme)
        }
        .scrollContentBackground(.hidden)
        .background(PulseScreenBackground())
        .foregroundStyle(PulseDesign.appInk(for: visualTheme))
        .tint(PulseDesign.appAccent(for: visualTheme))
        .pulseSoftScrollEdges()
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .pulseSecondaryNavigation(isEnabled: mode == .settings)
        .disabled(model.operation != nil)
        .pulseBottomBar {
            saveArea
        }
    }

    private var onboardingIntroduction: some View {
        Section {
            VStack(alignment: .leading, spacing: PulseDesign.spacing20) {
                sealPreview

                Text("commitment.onboarding.title")
                    .font(PulseDesign.displayFont(size: 30, relativeTo: .largeTitle).weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, PulseDesign.spacing16)
            .accessibilityElement(children: .contain)
        }
        .listRowBackground(Color.clear)
    }

    /// The seal the name will be carved into; it inks itself once the name can be kept.
    private var sealPreview: some View {
        let palette = PulseDesign.palette(for: visualTheme)
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let shownName = trimmed.isEmpty
            ? PulseLocalization.string("commitment.name.placeholder", locale: locale)
            : trimmed
        let seed = PulseSealSeed.value(for: shownName)
        return ZStack {
            PulseSealSlot(inscription: .name(shownName), tint: palette.seal)
                .opacity(canSubmit ? 0 : 1)
            PulseSealImpression(inscription: .name(shownName), ink: palette.seal, seed: seed)
                .rotationEffect(PulseSealSeed.tilt(for: seed))
                .opacity(canSubmit ? 1 : 0)
        }
        .frame(width: 112, height: 112)
        .animation(.easeOut(duration: 0.22), value: canSubmit)
        .accessibilityHidden(true)
    }

    /// The live count sits in the field's own row, so it stays in sight while the keyboard is up.
    @ViewBuilder
    private var identityFields: some View {
        Section {
            HStack(alignment: .firstTextBaseline, spacing: PulseDesign.spacing12) {
                TextField("commitment.name.placeholder", text: $name)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .name)
                    .onSubmit {
                        focusedField = .purpose
                    }
                    .accessibilityIdentifier("commitment.name.field")

                characterCount(
                    value: name,
                    minimum: HabitIdentity.minimumNameLength,
                    maximum: HabitIdentity.maximumNameLength,
                    identifier: "commitment.name.count"
                )
            }
        } header: {
            Text("commitment.section")
        } footer: {
            Text(
                String(
                    format: PulseLocalization.string(
                        "commitment.name.requirement_format",
                        locale: locale
                    ),
                    locale: locale,
                    Int64(HabitIdentity.minimumNameLength),
                    Int64(HabitIdentity.maximumNameLength)
                )
            )
            .foregroundStyle(nameLengthIsInvalid
                ? PulseDesign.systemDestructive
                : PulseDesign.appMuted(for: visualTheme))
        }

        Section {
            HStack(alignment: .firstTextBaseline, spacing: PulseDesign.spacing12) {
                TextField(
                    "commitment.purpose.placeholder",
                    text: $purpose,
                    axis: .vertical
                )
                .lineLimit(2...4)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)
                .focused($focusedField, equals: .purpose)
                .onSubmit {
                    focusedField = nil
                }
                .accessibilityIdentifier("commitment.purpose.field")

                characterCount(
                    value: purpose,
                    maximum: HabitIdentity.maximumPurposeLength,
                    identifier: "commitment.purpose.count"
                )
            }
        } footer: {
            Text("commitment.privacy_note")
                .foregroundStyle(PulseDesign.appMuted(for: visualTheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var saveArea: some View {
        VStack(spacing: 0) {
            Button {
                focusedField = nil
                Task {
                    if await model.updateHabitIdentity(name: name, purpose: purpose),
                       mode == .settings {
                        dismiss()
                    }
                }
            } label: {
                HStack {
                    Spacer()
                    if model.operation == .updateHabitIdentity {
                        ProgressView()
                            .tint(PulseDesign.appAccentForeground(for: visualTheme))
                    } else {
                        Text(saveButtonTitle)
                            .font(.headline.weight(.semibold))
                    }
                    Spacer()
                }
                .frame(minHeight: PulseDesign.minimumHitTarget)
                .foregroundStyle(PulseDesign.appAccentForeground(for: visualTheme))
            }
            .buttonStyle(.borderedProminent)
            .tint(PulseDesign.appAccent(for: visualTheme))
            .frame(maxWidth: .infinity)
            .padding(.horizontal, PulseDesign.horizontalPadding)
            .padding(.vertical, PulseDesign.spacing12)
            .disabled(model.operation != nil || !canSubmit)
            .accessibilityIdentifier("commitment.save.button")
        }
        .padding(.top, PulseDesign.spacing24)
    }

    private func characterCount(
        value: String,
        minimum: Int? = nil,
        maximum: Int,
        identifier: String
    ) -> some View {
        Text(verbatim: "\(value.count)/\(maximum)")
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(isInvalidLength(value, minimum: minimum, maximum: maximum)
                ? PulseDesign.systemDestructive
                : PulseDesign.appMuted(for: visualTheme))
            .accessibilityIdentifier(identifier)
    }

    private var nameLengthIsInvalid: Bool {
        isInvalidLength(
            name,
            minimum: HabitIdentity.minimumNameLength,
            maximum: HabitIdentity.maximumNameLength
        )
    }

    private func isInvalidLength(_ value: String, minimum: Int?, maximum: Int) -> Bool {
        value.count > maximum || (!value.isEmpty && value.count < (minimum ?? 0))
    }

    private var canSubmit: Bool {
        (try? HabitIdentity(userName: name, userPurpose: purpose)) != nil
    }

    private var navigationTitle: LocalizedStringKey {
        mode == .onboarding ? "commitment.onboarding.navigation_title" : "commitment.navigation_title"
    }

    private var saveButtonTitle: LocalizedStringKey {
        mode == .onboarding ? "commitment.onboarding.continue" : "commitment.save"
    }
}
