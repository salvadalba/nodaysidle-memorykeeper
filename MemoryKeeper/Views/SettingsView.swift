import SwiftUI
import ServiceManagement

struct SettingsView: View {
    private enum Tabs: Hashable {
        case general, analysis, appearance
    }

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(Tabs.general)

            AnalysisSettingsView()
                .tabItem {
                    Label("Analysis", systemImage: "wand.and.stars")
                }
                .tag(Tabs.analysis)

            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
                .tag(Tabs.appearance)
        }
        .frame(width: 480, height: 320)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showInMenuBar") private var showInMenuBar = true
    @AppStorage("memoryNotifications") private var memoryNotifications = true
    @AppStorage("dailyMemoryHour") private var dailyMemoryHour = 9

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }

                Toggle("Show in menu bar", isOn: $showInMenuBar)
            } header: {
                Text("Startup")
            }

            Section {
                Toggle("Show memory notifications", isOn: $memoryNotifications)

                Picker("Daily memory time", selection: $dailyMemoryHour) {
                    ForEach(6..<22) { hour in
                        Text(formatHour(hour)).tag(hour)
                    }
                }
            } header: {
                Text("Notifications")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let date = Calendar.current.date(from: DateComponents(hour: hour)) ?? Date()
        return formatter.string(from: date)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to set launch at login: \(error)")
        }
    }
}

// MARK: - Analysis Settings

struct AnalysisSettingsView: View {
    @AppStorage("similarityThreshold") private var similarityThreshold = 0.5
    @AppStorage("categorizationConfidence") private var categorizationConfidence = 0.7
    @AppStorage("forgottenMonths") private var forgottenMonths = 12
    @AppStorage("excludeFavorites") private var excludeFavorites = false
    @AppStorage("maxCategoriesPerPhoto") private var maxCategoriesPerPhoto = 5

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Similarity threshold")
                        Spacer()
                        Text(String(format: "%.0f%%", (1 - similarityThreshold) * 100))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $similarityThreshold, in: 0.3...0.8)
                    Text("Lower values find more duplicates but may include false positives")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Duplicate Detection")
            }

            Section {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Minimum confidence")
                        Spacer()
                        Text(String(format: "%.0f%%", categorizationConfidence * 100))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $categorizationConfidence, in: 0.5...0.9)
                }

                Stepper("Max categories per photo: \(maxCategoriesPerPhoto)", value: $maxCategoriesPerPhoto, in: 1...10)
            } header: {
                Text("Categorization")
            }

            Section {
                Stepper("Consider photos forgotten after \(forgottenMonths) months", value: $forgottenMonths, in: 6...36)
                Toggle("Exclude favorites from forgotten photos", isOn: $excludeFavorites)
            } header: {
                Text("Memory Surfacing")
            }

            Section {
                Button("Reset to Defaults") {
                    resetToDefaults()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func resetToDefaults() {
        similarityThreshold = 0.5
        categorizationConfidence = 0.7
        forgottenMonths = 12
        excludeFavorites = false
        maxCategoriesPerPhoto = 5
    }
}

// MARK: - Appearance Settings

struct AppearanceSettingsView: View {
    @AppStorage("thumbnailSize") private var thumbnailSize = 1
    @AppStorage("gridSpacing") private var gridSpacing = 8.0
    @AppStorage("reduceAnimations") private var reduceAnimations = false
    @AppStorage("showPhotoMetadata") private var showPhotoMetadata = true

    var body: some View {
        Form {
            Section {
                Picker("Thumbnail size", selection: $thumbnailSize) {
                    Text("Small").tag(0)
                    Text("Medium").tag(1)
                    Text("Large").tag(2)
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading) {
                    HStack {
                        Text("Grid spacing")
                        Spacer()
                        Text("\(Int(gridSpacing))px")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $gridSpacing, in: 2...20, step: 2)
                }
            } header: {
                Text("Photo Grid")
            }

            Section {
                Toggle("Reduce animations", isOn: $reduceAnimations)
                Toggle("Show photo metadata", isOn: $showPhotoMetadata)
            } header: {
                Text("Display")
            }

            Section {
                HStack {
                    Text("Preview")
                    Spacer()
                }

                thumbnailPreview
            } header: {
                Text("Preview")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var thumbnailPreview: some View {
        HStack(spacing: gridSpacing) {
            ForEach(0..<3) { _ in
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
                    .frame(width: previewSize, height: previewSize)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.tertiary)
                    }
            }
        }
        .animation(reduceAnimations ? nil : .easeInOut, value: gridSpacing)
        .animation(reduceAnimations ? nil : .easeInOut, value: thumbnailSize)
    }

    private var previewSize: CGFloat {
        switch thumbnailSize {
        case 0: return 40
        case 2: return 80
        default: return 60
        }
    }
}

#Preview {
    SettingsView()
}
