import SwiftUI

struct AccountView: View {
    @Environment(AuthService.self) private var authService
    @Environment(SyncService.self) private var syncService
    @Environment(\.dismiss) private var dismiss

    @State private var showingSignOutAlert = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                syncSection
                signOutSection
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .alert("Sign out?", isPresented: $showingSignOutAlert) {
                Button("Sign out", role: .destructive) {
                    Task { await authService.signOut() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your data will be cleared from this device. It will be restored next time you sign in.")
            }
        }
    }

    // MARK: - Subviews

    private var accountSection: some View {
        Section("Account") {
            Label(authService.session?.userID ?? "—", systemImage: SFSymbol.Auth.account)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var syncSection: some View {
        Section("Sync") {
            HStack {
                Label("Status", systemImage: SFSymbol.Auth.sync)
                Spacer()
                if syncService.isSyncing {
                    ProgressView()
                        .controlSize(.small)
                } else if let error = syncService.lastSyncError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                } else {
                    Text("Up to date")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button("Sync now") {
                Task { await syncService.sync() }
            }
            .disabled(syncService.isSyncing)
        }
    }

    private var signOutSection: some View {
        Section {
            Button(role: .destructive) {
                showingSignOutAlert = true
            } label: {
                Label("Sign out", systemImage: SFSymbol.Auth.signOut)
            }
        }
    }
}
