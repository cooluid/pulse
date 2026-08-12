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
        }
        .scrollContentBackground(.hidden)
        .background(PulseScreenBackground())
        .foregroundStyle(PulseDesign.ink)
        .tint(PulseDesign.tint)
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
                PulseBrandMark(size: PulseDesign.recordDetailBrandMarkSize)

                Text("commitment.onboarding.title")
                    .font(.title.bold())

                Text("commitment.onboarding.message")
                    .font(.body)
                    .foregroundStyle(PulseDesign.secondary)
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
                .foregroundStyle(PulseDesign.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } header: {
            Text("commitment.section")
        } footer: {
            Text("commitment.fields.footer")
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
                            .tint(PulseDesign.actionForeground)
                    } else {
                        Text(saveButtonTitle)
                            .font(.headline)
                    }
                    Spacer()
                }
                .frame(minHeight: PulseDesign.minimumHitTarget)
            }
            .buttonStyle(.borderedProminent)
            .tint(PulseDesign.action)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, PulseDesign.horizontalPadding)
            .padding(.vertical, PulseDesign.spacing12)
            .disabled(model.operation != nil || !canSubmit)
            .accessibilityIdentifier("commitment.save.button")
        }
        .background(PulseDesign.background)
    }

    private func characterCount(
        value: String,
        maximum: Int,
        identifier: String
    ) -> some View {
        Text("\(value.count)/\(maximum)")
            .font(.caption.monospacedDigit())
            .foregroundStyle(value.count > maximum ? PulseDesign.action : PulseDesign.secondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityIdentifier(identifier)
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
