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
                .listRowBackground(PulseDesign.appSurface(for: visualTheme))
                .listRowSeparatorTint(PulseDesign.appDivider(for: visualTheme))
        }
        .scrollContentBackground(.hidden)
        .background {
            ZStack {
                PulseScreenBackground()
                PulseFieldBackground()
            }
        }
        .foregroundStyle(PulseDesign.appInk(for: visualTheme))
        .tint(PulseDesign.appAccent(for: visualTheme))
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .pulseSecondaryNavigation(isEnabled: mode == .settings)
        .disabled(model.operation != nil)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            saveArea
        }
    }

    private var onboardingIntroduction: some View {
        Section {
            VStack(alignment: .leading, spacing: PulseDesign.spacing16) {
                PulseBrandMark(size: PulseDesign.onboardingBrandMarkSize)

                Text("commitment.onboarding.title")
                    .font(.largeTitle.bold())
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, PulseDesign.spacing16)
            .accessibilityElement(children: .contain)
        }
        .listRowBackground(Color.clear)
    }

    private var identityFields: some View {
        Section {
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

            Text("commitment.privacy_note")
                .font(.footnote)
                .foregroundStyle(PulseDesign.appMuted(for: visualTheme))
                .fixedSize(horizontal: false, vertical: true)
        } header: {
            Text("commitment.section")
        }
    }

    private var saveArea: some View {
        VStack(spacing: 0) {
            Divider()

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
        .background(PulseDesign.appSurface(for: visualTheme))
    }

    private func characterCount(
        value: String,
        minimum: Int? = nil,
        maximum: Int,
        identifier: String
    ) -> some View {
        HStack {
            if let minimum {
                Text(
                    String(
                        format: PulseLocalization.string(
                            "commitment.name.requirement_format",
                            locale: locale
                        ),
                        locale: locale,
                        Int64(minimum),
                        Int64(maximum)
                    )
                )
            }

            Spacer()

            Text(verbatim: "\(value.count)/\(maximum)")
                .monospacedDigit()
        }
        .font(.caption)
        .foregroundStyle(isInvalidLength(value, minimum: minimum, maximum: maximum)
            ? PulseDesign.systemDestructive
            : PulseDesign.appMuted(for: visualTheme))
        .accessibilityIdentifier(identifier)
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
