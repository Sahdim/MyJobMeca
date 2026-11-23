import SwiftUI
import UIKit
import MessageUI

@main
struct MonJobMecaApp: App {
    @StateObject private var store = AppStore()

    init() {
        // Barres en verre dépoli sur fond noir, titres blancs
        let nav = UINavigationBarAppearance()
        nav.configureWithDefaultBackground()
        nav.backgroundEffect = UIBlurEffect(style: .systemChromeMaterialDark)
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        nav.titleTextAttributes = [.foregroundColor: UIColor.white]
        let navBord = UINavigationBarAppearance()
        navBord.configureWithTransparentBackground()
        navBord.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        navBord.titleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = navBord
        UINavigationBar.appearance().tintColor = .white

        let tab = UITabBarAppearance()
        tab.configureWithDefaultBackground()
        tab.backgroundEffect = UIBlurEffect(style: .systemChromeMaterialDark)
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }

    var body: some Scene {
        WindowGroup {
            Racine()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .tint(.white)
        }
    }
}

struct Racine: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.scenePhase) private var phase
    @State private var onglet = 0
    @State private var page: PageCandidature?

    var body: some View {
        let aTraiter = store.data.offres.filter { store.statut(.offre, $0.id) == "a_traiter" }.count
        let nRelances = store.relances.count
        TabView(selection: $onglet) {
            VueAccueil(onglet: $onglet)
                .tabItem { Label("Accueil", systemImage: "house.fill") }.tag(0)
            VueOffres()
                .tabItem { Label("Offres", systemImage: "briefcase.fill") }.tag(1)
                .badge(aTraiter)
            VueMarche()
                .tabItem { Label("Marché", systemImage: "building.2.fill") }.tag(2)
            VueSuivi()
                .tabItem { Label("Suivi", systemImage: "list.bullet.rectangle.portrait.fill") }.tag(3)
                .badge(nRelances)
            VueProfil()
                .tabItem { Label("Profil", systemImage: "person.crop.circle.fill") }.tag(4)
        }
        .overlay(alignment: .top) {
            if let m = store.message {
                Text(m)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 8).padding(.horizontal, 24)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        // Annonce ouverte DANS l'appli pour postuler (lettre déjà copiée)
        .fullScreenCover(item: $store.pageCandidature, onDismiss: {
            if let p = page { store.finCandidature(p) }
            page = nil
        }) { p in
            PageWeb(url: p.url)
                .ignoresSafeArea()
                .onAppear { page = p }
        }
        // Question au retour
        .alert("Candidature envoyée ?", isPresented: Binding(get: { store.question != nil }, set: { if !$0 { store.question = nil } }), presenting: store.question) { o in
            Button("Oui, c'est envoyé") { store.changerStatut(.offre, o.id, "postule"); store.question = nil }
            Button("Pas encore", role: .cancel) { store.question = nil }
        } message: { o in
            Text("\(o.poste)\n\(o.entreprise)")
        }
        // E-mail de candidature spontanée, avec la lettre et le CV
        .sheet(item: $store.mail) { m in
            if MFMailComposeViewController.canSendMail() {
                FenetreMail(mail: m) { envoye in
                    if envoye { store.changerStatut(.ent, m.entrepriseID, "envoyee") }
                    store.mail = nil
                }
                .ignoresSafeArea()
            } else {
                PasDeMail(mail: m)
            }
        }
        .task { await store.actualiser() }
        .onChange(of: phase) { p in
            if p == .active { Task { await store.actualiser() } }
        }
    }
}

/// Si l'app Mail n'est pas configurée : on partage la lettre (et le CV) avec l'app de son choix.
struct PasDeMail: View {
    @EnvironmentObject var store: AppStore
    let mail: MailCandidature
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("L'app Mail n'est pas configurée sur cet iPhone. Envoie ta candidature à \(mail.destinataire) avec Gmail ou Outlook :")
                    .font(.system(size: 15)).foregroundColor(.texte2)
                Button {
                    UIPasteboard.general.string = mail.destinataire
                    store.toast("Adresse copiée")
                } label: { Label(mail.destinataire, systemImage: "envelope.fill") }
                    .buttonStyle(BoutonGris())
                if let cv = mail.cv {
                    ShareLink(items: [cv], subject: Text(mail.objet), message: Text(mail.corps)) {
                        Label("Envoyer lettre + CV", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(BoutonBlanc())
                } else {
                    ShareLink(item: mail.corps, subject: Text(mail.objet)) {
                        Label("Envoyer ma lettre", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(BoutonBlanc())
                }
                Spacer()
            }
            .padding(16)
            .background(Color.fond.ignoresSafeArea())
            .navigationTitle("Envoyer")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}
