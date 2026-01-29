import SwiftUI
import SwiftData

struct MenuBarView: View {
    @Query(sort: \Memory.createdDate, order: .reverse) private var memories: [Memory]
    @Environment(\.openWindow) private var openWindow

    private var todaysMemory: Memory? {
        memories.first { Calendar.current.isDateInToday($0.createdDate) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("MemoryKeeper")
                    .font(Typography.sectionSmall)
                Spacer()
                statusIndicator
            }

            Divider()

            // Today's memory
            if let memory = todaysMemory {
                todayMemoryCard(memory)
            } else {
                noMemoryCard
            }

            Divider()

            // Quick actions
            quickActions
        }
        .padding()
        .frame(width: 300)
    }

    private var statusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(.green)
                .frame(width: 8, height: 8)
            Text("Ready")
                .font(Typography.metadataSmall)
                .foregroundStyle(.secondary)
        }
    }

    private func todayMemoryCard(_ memory: Memory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's Memory")
                .font(Typography.tagLarge)
                .foregroundStyle(.secondary)

            // Preview image
            RoundedRectangle(cornerRadius: 12)
                .fill(.quaternary)
                .frame(height: 150)
                .overlay {
                    VStack {
                        Image(systemName: memoryIcon(for: memory.type))
                            .font(.largeTitle)
                            .foregroundStyle(.tertiary)

                        if let caption = memory.caption {
                            Text(caption.text)
                                .font(Typography.captionSmall)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                }

            HStack {
                Label("\(memory.photos.count) photos", systemImage: "photo.on.rectangle")
                    .font(Typography.metadataSmall)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("View") {
                    openMainApp()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }

    private var noMemoryCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)

            Text("No memory today")
                .font(Typography.bodySmall)
                .foregroundStyle(.secondary)

            Button("Generate Memory") {
                // TODO: Trigger memory generation
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var quickActions: some View {
        VStack(spacing: 4) {
            Button {
                openMainApp()
            } label: {
                HStack {
                    Label("Open MemoryKeeper", systemImage: "photo.on.rectangle")
                    Spacer()
                    Text("O")
                        .font(Typography.metadataSmall)
                        .foregroundStyle(.secondary)
                }
            }
            .keyboardShortcut("o", modifiers: [])
            .buttonStyle(.plain)
            .padding(.vertical, 4)

            Button {
                // TODO: Trigger refresh
            } label: {
                HStack {
                    Label("Refresh Memory", systemImage: "arrow.clockwise")
                    Spacer()
                    Text("R")
                        .font(Typography.metadataSmall)
                        .foregroundStyle(.secondary)
                }
            }
            .keyboardShortcut("r", modifiers: [])
            .buttonStyle(.plain)
            .padding(.vertical, 4)

            Divider()

            Button {
                openSettings()
            } label: {
                HStack {
                    Label("Settings...", systemImage: "gear")
                    Spacer()
                    Text(",")
                        .font(Typography.metadataSmall)
                        .foregroundStyle(.secondary)
                }
            }
            .keyboardShortcut(",", modifiers: [])
            .buttonStyle(.plain)
            .padding(.vertical, 4)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Label("Quit MemoryKeeper", systemImage: "power")
                    Spacer()
                    Text("Q")
                        .font(Typography.metadataSmall)
                        .foregroundStyle(.secondary)
                }
            }
            .keyboardShortcut("q", modifiers: [])
            .buttonStyle(.plain)
            .padding(.vertical, 4)
        }
    }

    private func memoryIcon(for type: MemoryType) -> String {
        switch type {
        case .onThisDay: return "calendar"
        case .forgotten: return "clock.arrow.circlepath"
        case .collection: return "rectangle.stack"
        }
    }

    private func openMainApp() {
        NSWorkspace.shared.open(URL(string: "memorykeeper://open")!)
    }

    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}

#Preview {
    MenuBarView()
        .modelContainer(for: [Memory.self, Photo.self, Caption.self], inMemory: true)
}
