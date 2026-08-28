import Foundation
import PulseCore
import WidgetKit

enum PulseWidgetEntryState {
    case placeholder
    case ready(PulseWidgetSnapshot, PulseWidgetStyle)
    case enhancementRequired
    case needsOpenApp
    case unavailable
}

struct PulseWidgetEntry: TimelineEntry {
    let date: Date
    let state: PulseWidgetEntryState
    let language: PulseInterfaceLanguage
}

@MainActor
enum PulseWidgetTimelineLoader {
    struct TimelineResult {
        let entries: [PulseWidgetEntry]
        let policy: TimelineReloadPolicy

        var timeline: Timeline<PulseWidgetEntry> {
            Timeline(entries: entries, policy: policy)
        }
    }

    static func loadTimeline(
        at date: Date,
        requestedStyle: PulseWidgetStyle,
        hasEnhancementEntitlement: Bool
    ) -> Timeline<PulseWidgetEntry> {
        let context: PulseWidgetSharedRuntime.Context
        let language: PulseInterfaceLanguage
        do {
            context = try PulseWidgetSharedRuntime.makeContext()
            language = try context.sharedSettings.load().language
        } catch {
            return failureTimeline(
                at: date,
                state: .unavailable,
                language: .system,
                retryAfter: PulseWidgetContract.runtimeRetryInterval
            ).timeline
        }

        do {
            try PulseWidgetSharedRuntime.requireExistingStore(at: context.location)
            let repository = try PulseWidgetSharedRuntime.makeRepository(
                at: context.location,
                clock: FixedPulseClock(now: date)
            )
            guard PulseWidgetStyleAccessPolicy.isAvailable(
                requestedStyle,
                hasEnhancementEntitlement: hasEnhancementEntitlement
            ) else {
                return failureTimeline(
                    at: date,
                    state: .enhancementRequired,
                    language: language,
                    retryAfter: PulseEnhancementContract.entitlementRefreshInterval
                ).timeline
            }
            guard let plan = try PulseWidgetSnapshotReader.readTimelinePlan(
                repository: repository,
                at: date
            ) else {
                throw PulseWidgetSharedRuntime.RuntimeError.missingPrimaryHabit
            }
            let entries = plan.entries.map { timelineEntry in
                PulseWidgetEntry(
                    date: timelineEntry.date,
                    state: .ready(timelineEntry.snapshot, requestedStyle),
                    language: language
                )
            }
            return TimelineResult(entries: entries, policy: .atEnd).timeline
        } catch PulseWidgetSharedRuntime.RuntimeError.sharedStoreMissing,
                PulseWidgetSharedRuntime.RuntimeError.missingPrimaryHabit {
            return failureTimeline(
                at: date,
                state: .needsOpenApp,
                language: language,
                retryAfter: PulseWidgetContract.runtimeRetryInterval
            ).timeline
        } catch PulseWidgetProjectionError.identityNotConfirmed {
            return failureTimeline(
                at: date,
                state: .needsOpenApp,
                language: language,
                retryAfter: PulseWidgetContract.runtimeRetryInterval
            ).timeline
        } catch {
            return failureTimeline(
                at: date,
                state: .unavailable,
                language: language,
                retryAfter: PulseWidgetContract.runtimeRetryInterval
            ).timeline
        }
    }

    private static func failureTimeline(
        at date: Date,
        state: PulseWidgetEntryState,
        language: PulseInterfaceLanguage,
        retryAfter: TimeInterval
    ) -> TimelineResult {
        TimelineResult(
            entries: [
                PulseWidgetEntry(
                    date: date,
                    state: state,
                    language: language
                ),
            ],
            policy: .after(date.addingTimeInterval(retryAfter))
        )
    }
}

extension PulseWidgetSnapshot {
    static var placeholder: PulseWidgetSnapshot {
        let generatedAt = Date.now
        let timeZone = TimeZone.current
        let today = LogicalDay.resolve(at: generatedAt, timeZone: timeZone)
        let days = (-6...0).map { offset in
            PulseWidgetDaySnapshot(
                day: today.addingDays(offset, timeZone: timeZone),
                state: offset == 0 ? .todayPending : (offset.isMultiple(of: 2) ? .checked : .missed)
            )
        }
        return PulseWidgetSnapshot(
            habitID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            habitName: String(localized: "widget.placeholder.commitment"),
            today: today,
            checkedAt: nil,
            recentDays: days,
            generatedAt: generatedAt,
            nextDayBoundary: today.addingDays(1, timeZone: timeZone).startDate(
                timeZone: timeZone
            ),
            projectTimeZoneIdentifier: timeZone.identifier
        )
    }
}
