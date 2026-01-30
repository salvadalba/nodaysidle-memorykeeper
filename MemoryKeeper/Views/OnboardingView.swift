import SwiftUI
import Photos

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    @State private var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let totalPages = 4

    var body: some View {
        ZStack {
            // Warm background
            Color.memoryWarmLight
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Page content - simple paging without TabView
                Group {
                    switch currentPage {
                    case 0: welcomePage
                    case 1: featuresPage
                    case 2: permissionPage
                    case 3: readyPage
                    default: welcomePage
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(currentPage)
                .animation(reduceMotion ? nil : .memorySpring, value: currentPage)

                // Bottom controls
                bottomControls
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .onAppear {
            checkAuthorizationStatus()
        }
    }

    // MARK: - Welcome Page

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 80))
                .foregroundStyle(Color.memoryAccent)
                .accessibilityHidden(true)

            Text("Welcome to MemoryKeeper")
                .font(Typography.heroLarge)
                .foregroundStyle(Color.memoryTextPrimary)
                .multilineTextAlignment(.center)

            Text("Rediscover your forgotten photos and relive your memories")
                .font(Typography.bodyLarge)
                .foregroundStyle(Color.memoryTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Welcome to MemoryKeeper. Rediscover your forgotten photos and relive your memories.")
    }

    // MARK: - Features Page

    private var featuresPage: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("What MemoryKeeper Does")
                .font(Typography.heroSmall)
                .foregroundStyle(Color.memoryTextPrimary)

            VStack(alignment: .leading, spacing: 20) {
                featureRow(
                    icon: "square.on.square",
                    title: "Find Duplicates",
                    description: "Automatically detect and clean up similar photos"
                )

                featureRow(
                    icon: "tag.fill",
                    title: "Smart Categories",
                    description: "Photos are organized by content using AI"
                )

                featureRow(
                    icon: "sparkles",
                    title: "Surface Memories",
                    description: "Rediscover forgotten photos from years past"
                )

                featureRow(
                    icon: "text.quote",
                    title: "Editorial Captions",
                    description: "Beautiful captions generated for your memories"
                )
            }
            .padding(.horizontal, 60)

            Spacer()
        }
        .padding()
        .accessibilityElement(children: .contain)
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.memoryAccent)
                .frame(width: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Typography.sectionSmall)
                    .foregroundStyle(Color.memoryTextPrimary)

                Text(description)
                    .font(Typography.bodySmall)
                    .foregroundStyle(Color.memoryTextSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(description)")
    }

    // MARK: - Permission Page

    private var permissionPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "photo.badge.checkmark")
                .font(.system(size: 60))
                .foregroundStyle(Color.memoryAccent)
                .accessibilityHidden(true)

            Text("Photo Library Access")
                .font(Typography.heroSmall)
                .foregroundStyle(Color.memoryTextPrimary)

            Text("MemoryKeeper needs access to your photos to analyze them locally on your device. Your photos never leave your Mac.")
                .font(Typography.bodyMedium)
                .foregroundStyle(Color.memoryTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 60)

            permissionButton

            privacyNote

            Spacer()
        }
        .padding()
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var permissionButton: some View {
        switch authorizationStatus {
        case .authorized, .limited:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Access Granted")
                    .font(Typography.bodyMedium)
                    .foregroundStyle(Color.memoryTextPrimary)
            }
            .padding()
            .accessibilityLabel("Photo library access granted")

        case .denied, .restricted:
            VStack(spacing: 12) {
                Text("Access Denied")
                    .font(Typography.bodyMedium)
                    .foregroundStyle(.red)

                Button("Open System Settings") {
                    openPhotoPrivacySettings()
                }
                .buttonStyle(.bordered)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Photo library access denied. Open System Settings to grant access.")

        case .notDetermined:
            Button("Grant Photo Access") {
                requestPhotoAccess()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityHint("Opens a permission dialog to grant photo library access")

        @unknown default:
            EmptyView()
        }
    }

    private var privacyNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield")
                .foregroundStyle(Color.memoryFaded)
            Text("All processing happens on-device. Your photos are never uploaded.")
                .font(Typography.metadataSmall)
                .foregroundStyle(Color.memoryTextSecondary)
        }
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Privacy note: All processing happens on-device. Your photos are never uploaded.")
    }

    // MARK: - Ready Page

    private var readyPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "party.popper")
                .font(.system(size: 60))
                .foregroundStyle(Color.memoryGold)
                .accessibilityHidden(true)

            Text("You're All Set!")
                .font(Typography.heroSmall)
                .foregroundStyle(Color.memoryTextPrimary)

            Text("MemoryKeeper will now analyze your photos in the background. Check back soon to discover your forgotten memories.")
                .font(Typography.bodyMedium)
                .foregroundStyle(Color.memoryTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 60)

            Button("Get Started") {
                completeOnboarding()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.return, modifiers: [])
            .accessibilityHint("Complete onboarding and start using MemoryKeeper")

            Spacer()
        }
        .padding()
        .accessibilityElement(children: .contain)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack {
            // Skip button (not on last page)
            if currentPage < totalPages - 1 {
                Button("Skip") {
                    completeOnboarding()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityHint("Skip onboarding and go directly to the app")
            } else {
                Spacer()
                    .frame(width: 50)
            }

            Spacer()

            // Page indicators
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Color.memoryAccent : Color.memoryFaded)
                        .frame(width: 8, height: 8)
                        .animation(reduceMotion ? nil : .memorySpring, value: currentPage)
                }
            }
            .accessibilityLabel("Page \(currentPage + 1) of \(totalPages)")

            Spacer()

            // Navigation buttons
            HStack(spacing: 12) {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation(.memorySpring) {
                            currentPage -= 1
                        }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityHint("Go to previous page")
                }

                if currentPage < totalPages - 1 {
                    Button("Next") {
                        withAnimation(.memorySpring) {
                            currentPage += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: [])
                    .accessibilityHint("Go to next page")
                }
            }
        }
    }

    // MARK: - Actions

    private func checkAuthorizationStatus() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    private func requestPhotoAccess() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                authorizationStatus = status
                if status == .authorized || status == .limited {
                    // Auto-advance to next page on success
                    withAnimation(.memorySpring) {
                        currentPage = min(currentPage + 1, totalPages - 1)
                    }
                }
            }
        }
    }

    private func openPhotoPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos") {
            NSWorkspace.shared.open(url)
        }
    }

    private func completeOnboarding() {
        withAnimation(.memorySpring) {
            isPresented = false
        }
    }
}

// MARK: - Onboarding Container

struct OnboardingContainerView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var photoAuthStatus: PHAuthorizationStatus = .notDetermined

    var body: some View {
        Group {
            if hasCompletedOnboarding && photoAuthStatus == .authorized {
                ContentView()
            } else if hasCompletedOnboarding && photoAuthStatus == .limited {
                ContentView()
            } else {
                OnboardingView(isPresented: Binding(
                    get: { !hasCompletedOnboarding },
                    set: { if !$0 { hasCompletedOnboarding = true } }
                ))
            }
        }
        .onAppear {
            photoAuthStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        }
    }
}

#Preview("Onboarding") {
    OnboardingView(isPresented: .constant(true))
}

#Preview("Onboarding Container") {
    OnboardingContainerView()
        .modelContainer(for: [Photo.self, Category.self, DuplicateGroup.self, Memory.self, Caption.self], inMemory: true)
}
