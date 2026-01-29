import SwiftUI

// MARK: - Error Alert Modifier

struct ErrorAlertModifier: ViewModifier {
    @Binding var error: Error?
    var onDismiss: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .alert(
                "Error",
                isPresented: Binding(
                    get: { error != nil },
                    set: { if !$0 { error = nil; onDismiss?() } }
                ),
                presenting: error
            ) { _ in
                Button("OK", role: .cancel) { }
            } message: { error in
                Text(error.localizedDescription)
            }
    }
}

extension View {
    func errorAlert(_ error: Binding<Error?>, onDismiss: (() -> Void)? = nil) -> some View {
        modifier(ErrorAlertModifier(error: error, onDismiss: onDismiss))
    }
}

// MARK: - Toast Notification

struct ToastView: View {
    let message: String
    let type: ToastType

    enum ToastType {
        case info, success, warning, error

        var icon: String {
            switch self {
            case .info: return "info.circle"
            case .success: return "checkmark.circle"
            case .warning: return "exclamationmark.triangle"
            case .error: return "xmark.circle"
            }
        }

        var color: Color {
            switch self {
            case .info: return .blue
            case .success: return .green
            case .warning: return .orange
            case .error: return .red
            }
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .foregroundStyle(type.color)

            Text(message)
                .font(Typography.bodySmall)

            Spacer()
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .padding(.horizontal)
    }
}

// MARK: - Toast Presenter

@Observable
@MainActor
class ToastPresenter {
    var currentToast: (message: String, type: ToastView.ToastType)?
    private var dismissTask: Task<Void, Never>?

    func show(_ message: String, type: ToastView.ToastType = .info, duration: TimeInterval = 3) {
        dismissTask?.cancel()
        currentToast = (message, type)

        dismissTask = Task {
            try? await Task.sleep(for: .seconds(duration))
            if !Task.isCancelled {
                withAnimation {
                    self.currentToast = nil
                }
            }
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        withAnimation {
            currentToast = nil
        }
    }
}

struct ToastModifier: ViewModifier {
    @Bindable var presenter: ToastPresenter

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let toast = presenter.currentToast {
                    ToastView(message: toast.message, type: toast.type)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 20)
                }
            }
            .animation(.spring(response: 0.3), value: presenter.currentToast != nil)
    }
}

extension View {
    func toastPresenter(_ presenter: ToastPresenter) -> some View {
        modifier(ToastModifier(presenter: presenter))
    }
}

// MARK: - Graceful Degradation State

@Observable
class AppHealthState {
    var isPhotoLibraryAvailable = true
    var isVisionAvailable = true
    var isDatabaseHealthy = true

    var isReadOnlyMode: Bool {
        !isDatabaseHealthy
    }

    var healthIssues: [HealthIssue] {
        var issues: [HealthIssue] = []

        if !isPhotoLibraryAvailable {
            issues.append(HealthIssue(
                title: "Photo Library Unavailable",
                message: "Grant photo library access in System Settings to use MemoryKeeper.",
                action: "Open Settings",
                actionHandler: { openPhotoSettings() }
            ))
        }

        if !isVisionAvailable {
            issues.append(HealthIssue(
                title: "Analysis Unavailable",
                message: "Photo analysis features are disabled. Your device may not support Vision framework.",
                action: nil,
                actionHandler: nil
            ))
        }

        if !isDatabaseHealthy {
            issues.append(HealthIssue(
                title: "Database Issue",
                message: "Running in read-only mode. Some features are disabled.",
                action: "Try Repair",
                actionHandler: { /* repair action */ }
            ))
        }

        return issues
    }
}

struct HealthIssue: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let action: String?
    let actionHandler: (() -> Void)?
}

private func openPhotoSettings() {
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos") {
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Health Banner

struct HealthBannerView: View {
    let issue: HealthIssue

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(issue.title)
                    .font(Typography.bodyMedium)
                    .fontWeight(.medium)

                Text(issue.message)
                    .font(Typography.metadataSmall)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let action = issue.action, let handler = issue.actionHandler {
                Button(action) {
                    handler()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview("Toast") {
    ToastView(message: "Photo library synced successfully", type: .success)
        .padding()
}

#Preview("Health Banner") {
    HealthBannerView(issue: HealthIssue(
        title: "Photo Library Unavailable",
        message: "Grant access in System Settings",
        action: "Open Settings",
        actionHandler: {}
    ))
    .padding()
}
