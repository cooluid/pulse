import Foundation

enum PulseExternalLinks {
    private static let site = URL(
        string: "https://fanr.co/pulse"
    )!

    static let privacyPolicy = site.appending(path: "privacy")
    static let support = site.appending(path: "support")
}
