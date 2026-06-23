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

    func sync(systemState: SystemTelemetryState, status: String, isConnected: Bool) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
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

        if let activity {
            Task { await activity.update(content) }
        } else {
            start(content: content)
        }
    }

    func end() {
        guard let activity else {
            return
        }

        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
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
