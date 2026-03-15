import SwiftUI

struct LoginView: View {
    @Environment(AuthService.self) private var authService

    @State private var showingMagicLink = false
    @State private var emailText = ""
    @State private var magicLinkSent = false
    @State private var errorMessage: String?
    @State private var isLoading = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()
            header
            Spacer()
            providerButtons
            Spacer()
        }
        .padding(DS.Spacing.xl)
        .sheet(isPresented: $showingMagicLink) {
            magicLinkSheet
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: SFSymbol.dashboard)
                .font(.system(size: DS.IconSize.lg))
                .foregroundStyle(.green)
            Text("Spendr")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Track your spending, anywhere.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var providerButtons: some View {
        VStack(spacing: DS.Spacing.md) {
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            oauthButton(label: "Continue with Apple", icon: SFSymbol.Auth.apple) {
                await signIn(with: .apple)
            }

            oauthButton(label: "Continue with Google", icon: SFSymbol.Auth.google) {
                await signIn(with: .google)
            }

            Button("Sign in with email link") {
                showingMagicLink = true
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.top, DS.Spacing.sm)
        }
    }

    private func oauthButton(
        label: String,
        icon: String,
        action: @escaping () async -> Void
    ) -> some View {
        Button {
            Task { await action() }
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                Text(label)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(DS.Spacing.md)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        }
        .foregroundStyle(.primary)
        .disabled(isLoading)
    }

    private var magicLinkSheet: some View {
        NavigationStack {
            Form {
                Section("Your email") {
                    TextField("email@example.com", text: $emailText)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                if magicLinkSent {
                    Section {
                        Label("Link sent! Check your inbox.", systemImage: SFSymbol.success)
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("Magic link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingMagicLink = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { Task { await sendMagicLink() } }
                        .fontWeight(.semibold)
                        .disabled(emailText.isEmpty || magicLinkSent)
                }
            }
        }
    }

    // MARK: - Helpers

    private func signIn(with provider: OAuthProvider) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await authService.signIn(with: provider)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func sendMagicLink() async {
        guard !emailText.isEmpty else { return }
        do {
            try await authService.sendMagicLink(to: emailText)
            magicLinkSent = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
