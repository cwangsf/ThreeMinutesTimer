//
//  HomeView.swift
//  TimerWatch Watch App
//
//  Created by Cynthia Wang on 1/7/26.
//

import SwiftUI
import SwiftData
import ThreeMinutesTimerKit

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var timerManager = WatchTimerManager()
    let circleSize: CGFloat = 60

    var body: some View {
        VStack {
            Text("\(timerManager.currentInterval + 1)/10")
                .font(.title)
                .fontWeight(.bold)

            // Progress circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                    .frame(width: circleSize, height: circleSize)

                Circle()
                    .trim(from: 0, to: timerManager.intervalProgress)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: circleSize, height: circleSize)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: timerManager.intervalProgress)

                // Time remaining
                Text(timerManager.timeRemaining)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }

            // Status
            Text(timerManager.statusText)
                .font(.caption)
                .foregroundColor(timerManager.isRunning ? .blue : .secondary)

            // Control buttons
            HStack {
                if !timerManager.isRunning {
                    Button {
                        startNewSession()
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button {
                        timerManager.pause()
                    } label: {
                        Image(systemName: "pause.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        timerManager.stop()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.body)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding()
    }

    private func startNewSession() {
        let session = AlarmSession()
        modelContext.insert(session)
        timerManager.startSession(session: session)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: AlarmSession.self, inMemory: true)
}
