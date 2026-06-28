//
//  LiveActivityController.swift
//  PicoRC
//
//  Created by Laurynas on 2026-06-24.
//

import ActivityKit
import Foundation

@MainActor
final class LiveActivityController {
    private var activity: Activity<PicoRCLiveActivityAttributes>?

    init() {
        end()
        /*
        if ActivityAuthorizationInfo().areActivitiesEnabled {
            _ = reconciledActivity()
        } else {
            end()
        }
        */
    }

    func sync(systemState: SystemTelemetryState, status: String, isConnected: Bool) {
        /*
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            end()
            return
        }

        let content = ActivityContent(
            state: PicoRCLiveActivityAttributes.ContentState(
                cpuX10: systemState.cpuX10,
                cpuSpeedMHzX100: systemState.cpuSpeedMHzX100,
                status: status,
                isConnected: isConnected
            ),
            staleDate: nil
        )

        if let activity = reconciledActivity() {
            Task { await activity.update(content) }
        } else {
            start(content: content)
        }
        */
    }

    func end() {
        let activities = Activity<PicoRCLiveActivityAttributes>.activities
        activity = nil

        for activity in activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    private func reconciledActivity() -> Activity<PicoRCLiveActivityAttributes>? {
        let activities = Activity<PicoRCLiveActivityAttributes>.activities
        guard let firstActivity = activities.first else {
            activity = nil
            return nil
        }

        let keptActivity = activity.flatMap { rememberedActivity in
            activities.first { $0.id == rememberedActivity.id }
        } ?? firstActivity

        activity = keptActivity

        for activity in activities where activity.id != keptActivity.id {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }

        return keptActivity
    }

    private func start(content: ActivityContent<PicoRCLiveActivityAttributes.ContentState>) {
        do {
            activity = try Activity.request(
                attributes: PicoRCLiveActivityAttributes(),
                content: content,
                pushType: nil
            )
        } catch {
            activity = nil
        }
    }
}
