import SwiftUI

@main
struct SantoroMailApp: App {
    @StateObject private var store = Store()
    init() { Brand.registerFonts() }
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Brand.at)
                #if os(macOS)
                .frame(minWidth: 900, minHeight: 600)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 1320, height: 840)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Nuevo correo") { store.composeNew() }.keyboardShortcut("n")
            }
            CommandMenu("Correo") {
                Button("Actualizar") { Task { await store.refresh() } }.keyboardShortcut("r")
                Button("Marcar todo como leído") { Task { await store.markAllRead() } }.keyboardShortcut("l", modifiers: [.command, .shift])
            }
        }
        #endif
    }
}

struct RootView: View {
    @EnvironmentObject var s: Store
    @AppStorage("set.theme") private var theme = "system"
    var body: some View {
        ZStack {
            if !s.loggedIn { LoginView().transition(.opacity) }
            else if !s.booted { Splash().transition(.opacity) }
            else { MainView().transition(.opacity) }
        }
        .animation(.easeInOut(duration: 0.45), value: s.booted)
        .animation(.easeInOut(duration: 0.3), value: s.loggedIn)
        .preferredColorScheme(theme == "light" ? .light : theme == "dark" ? .dark : nil)
        .task { await s.start() }
        .alert("Santoro Mail", isPresented: Binding(get: { s.message != nil }, set: { if !$0 { s.message = nil } })) {
            Button("OK") { s.message = nil }
        } message: { Text(s.message ?? "") }
    }
}

struct LoginView: View {
    @EnvironmentObject var s: Store
    @State private var busy = false
    var body: some View {
        ZStack {
            Brand.wine.ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer()
                Image("RiderCream").resizable().scaledToFit().frame(width: 130)
                Text("SANTORO").font(Brand.f(20, .medium)).tracking(9).foregroundStyle(Brand.cream)
                Text("MAIL").font(Brand.f(12)).tracking(5).foregroundStyle(Brand.cream.opacity(0.7))
                Text("Hanif Hawlader").font(Brand.f(14)).foregroundStyle(Brand.cream.opacity(0.8)).padding(.top, 6)
                Spacer()
                Button {
                    busy = true
                    Task { await s.login(); busy = false }
                } label: {
                    HStack(spacing: 10) {
                        if busy { ProgressView().tint(Brand.wine) } else { Image(systemName: "envelope.fill") }
                        Text("Entrar con Microsoft").font(Brand.f(16, .medium))
                    }
                    .foregroundStyle(Brand.wine).padding(.horizontal, 28).padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Brand.cream))
                }
                .buttonStyle(.plain).disabled(busy)
                Text("contacto@hanifhawlader.com").font(Brand.f(12)).foregroundStyle(Brand.cream.opacity(0.6)).padding(.bottom, 40)
            }
        }
    }
}

extension Brand { static let cream = Color(red: 0.969, green: 0.961, blue: 0.914) }
