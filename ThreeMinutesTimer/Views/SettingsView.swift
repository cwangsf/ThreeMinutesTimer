//
//  SettingsView.swift
//  ThreeMinutesTimer
//
//  Created by Cynthia Wang on 8/23/25.
//

import SwiftUI
import ThreeMinutesTimerKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    var alarmManager: AlarmManager

    var body: some View {
        NavigationStack {
            Form {
                Section("Theme Color") {
                    ForEach(ThemeColor.allCases, id: \.self) { color in
                        HStack {
                            Circle()
                                .fill(color.color)
                                .frame(width: 30, height: 30)

                            Text(color.rawValue)

                            Spacer()

                            if alarmManager.themeColor == color {
                                Image(systemName: "checkmark")
                                    .foregroundColor(color.color)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            alarmManager.themeColor = color
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
