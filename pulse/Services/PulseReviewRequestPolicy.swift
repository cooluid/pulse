import Foundation

enum PulseAppStoreContract {
    static let appID = "6800603164"
    static let writeReviewURL = URL(
        string: "https://apps.apple.com/app/id\(appID)?action=write-review"
    )!
}

enum PulseReviewRequestPolicy {
    static let milestones = [7, 30, 100]
    static let presentationDelay: Duration = .seconds(2)

    static func nextMilestone(
        totalCheckInCount: Int,
        attemptedMilestones: Set<Int>
    ) -> Int? {
        guard let milestone = milestones.last(where: { $0 <= totalCheckInCount }),
              !attemptedMilestones.contains(milestone) else {
            return nil
        }
        return milestone
    }

    static func consumedMilestones(through milestone: Int) -> Set<Int> {
        Set(milestones.filter { $0 <= milestone })
    }
}
