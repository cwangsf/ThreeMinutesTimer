//
//  TimerWidgetLiveActivity.swift
//  TimerWidget
//
//  Created by Cynthia Wang on 1/6/26.
//

import ActivityKit
import WidgetKit
import SwiftUI
import ThreeMinutesTimerKit

// MARK: - Live Activity Widget
struct TimerWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerWidgetAttributes.self) { context in
            // Lock screen/banner UI
            LockScreenTimerView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI when user long-presses
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Interval")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(context.state.currentInterval + 1)/\(context.state.totalIntervals)")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Time Left")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(context.state.timeRemaining)
                            .font(.title2)
                            .fontWeight(.bold)
                            .monospacedDigit()
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    // Progress bar
                    VStack(spacing: 8) {
                        HStack {
                            Text(context.state.isRunning ? "Running" : "Paused")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Session started")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // Progress visualization
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.secondary.opacity(0.2))

                                // Progress
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(LinearGradient(
                                        colors: [.blue, .cyan],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                                    .frame(width: geometry.size.width * intervalProgress(context))
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding(.top, 8)
                }
            } compactLeading: {
                // Compact leading (left side of Dynamic Island)
                Text("\(context.state.currentInterval + 1)")
                    .font(.caption)
                    .fontWeight(.semibold)
            } compactTrailing: {
                // Compact trailing (right side of Dynamic Island)
                Text(context.state.timeRemaining)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            } minimal: {
                // Minimal view (when multiple Live Activities are running)
                Text("\(context.state.currentInterval + 1)")
                    .font(.caption2)
            }
            .keylineTint(Color.blue)
        }
    }

    // Calculate progress for current interval (0.0 to 1.0)
    private func intervalProgress(_ context: ActivityViewContext<TimerWidgetAttributes>) -> CGFloat {
        let intervalDuration = 180.0 // 3 minutes
        let elapsed = intervalDuration - Double(context.state.secondsRemaining)
        return CGFloat(elapsed / intervalDuration)
    }
}

// MARK: - Lock Screen View
struct LockScreenTimerView: View {
    let context: ActivityViewContext<TimerWidgetAttributes>

    var body: some View {
        HStack(spacing: 16) {
            // Left side: Interval info
            VStack(alignment: .leading, spacing: 4) {
                Text("Interval Timer")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    Text("Interval \(context.state.currentInterval + 1)/\(context.state.totalIntervals)")
                        .font(.headline)
                        .fontWeight(.semibold)

                    if !context.state.isRunning {
                        Image(systemName: "pause.circle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }
            }

            Spacer()

            // Right side: Time remaining
            VStack(alignment: .trailing, spacing: 4) {
                Text("Time Left")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(context.state.timeRemaining)
                    .font(.title2)
                    .fontWeight(.bold)
                    .monospacedDigit()
            }
        }
        .padding()
        .activityBackgroundTint(Color.blue.opacity(0.2))
        .activitySystemActionForegroundColor(Color.blue)
    }
}

// MARK: - Previews
extension TimerWidgetAttributes {
    fileprivate static var preview: TimerWidgetAttributes {
        TimerWidgetAttributes(sessionStartTime: Date())
    }
}

extension TimerWidgetAttributes.ContentState {
    fileprivate static var interval1: TimerWidgetAttributes.ContentState {
        TimerWidgetAttributes.ContentState(
            currentInterval: 0,
            totalIntervals: 10,
            timeRemaining: "3:00",
            secondsRemaining: 180,
            isRunning: true
        )
    }

    fileprivate static var interval5: TimerWidgetAttributes.ContentState {
        TimerWidgetAttributes.ContentState(
            currentInterval: 4,
            totalIntervals: 10,
            timeRemaining: "1:47",
            secondsRemaining: 107,
            isRunning: true
        )
    }

    fileprivate static var paused: TimerWidgetAttributes.ContentState {
        TimerWidgetAttributes.ContentState(
            currentInterval: 7,
            totalIntervals: 10,
            timeRemaining: "2:15",
            secondsRemaining: 135,
            isRunning: false
        )
    }
}

#Preview("Notification", as: .content, using: TimerWidgetAttributes.preview) {
   TimerWidgetLiveActivity()
} contentStates: {
    TimerWidgetAttributes.ContentState.interval1
    TimerWidgetAttributes.ContentState.interval5
    TimerWidgetAttributes.ContentState.paused
}
