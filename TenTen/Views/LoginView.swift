import SwiftUI

struct LoginView: View {
    @EnvironmentObject var supabase: SupabaseManager
    @State private var username = ""
    @State private var error = ""
    @State private var loading = false

    var body: some View {
        VStack(spacing: 30) {
            Text("🎙️ TenTen")
                .font(.largeTitle.bold())

            Text("Elige tu nombre de usuario")
                .foregroundColor(.secondary)

            TextField("Nombre de usuario", text: $username)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .padding(.horizontal)

            if !error.isEmpty {
                Text(error).foregroundColor(.red).font(.caption)
            }

            Button(loading ? "Entrando..." : "Entrar") {
                Task { await login() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(username.isEmpty || loading)
        }
        .padding()
    }

    func login() async {
        loading = true
        do {
            try await supabase.loadOrCreateUser(username: username)
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}
