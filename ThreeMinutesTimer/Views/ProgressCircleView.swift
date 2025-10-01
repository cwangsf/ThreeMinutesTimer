//
//  ProgressCircleView.swift
//  ThreeMinutesTimer
//
//  Created by Cynthia Wang on 8/23/25.
//
import SwiftUI

struct ProgressCircleView: View {
    let circleSize: CGFloat = 200
    let circleWidth: CGFloat = 12
    let repeatTime: Int = 3
    var alarmManager: AlarmManager
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: circleWidth)
                .frame(width: circleSize, height: circleSize)
            
            Circle()
                .trim(from: 0, to: alarmManager.progress)
                .stroke(
                    LinearGradient(
                        colors: alarmManager.themeColor.gradientColors,
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: circleWidth, lineCap: .round)
                )
                .frame(width: circleSize, height: circleSize)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: alarmManager.progress)

            VStack {
                Text(String(localized: .intervalTitle))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\(alarmManager.currentInterval + 1)/\(String(repeatTime))")
                    .font(.title)
                    .fontWeight(.bold)

                if alarmManager.isRunning {
                    Text(alarmManager.timeRemaining)
                        .font(.title2)
                        .foregroundColor(alarmManager.themeColor.color)
                        .monospacedDigit()
                }
            }
        }
    }
}
