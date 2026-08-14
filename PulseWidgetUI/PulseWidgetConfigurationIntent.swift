import AppIntents

extension PulseWidgetStyle: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation =
        "widget.configuration.style.title"

    static let caseDisplayRepresentations: [PulseWidgetStyle: DisplayRepresentation] = [
        .place: "widget.configuration.style.place",
        .orbit: "widget.configuration.style.orbit",
        .stack: "widget.configuration.style.stack",
        .bleed: "widget.configuration.style.bleed",
        .letter: "widget.configuration.style.letter",
        .field: "widget.configuration.style.field",
        .path: "widget.configuration.style.path",
        .tide: "widget.configuration.style.tide",
    ]
}

struct PulseWidgetConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "widget.configuration.intent.title"
    static let description = IntentDescription("widget.configuration.intent.description")

    @Parameter(
        title: "widget.configuration.style.parameter",
        default: .place
    )
    var style: PulseWidgetStyle
}
