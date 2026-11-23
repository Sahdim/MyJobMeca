import Foundation
import SwiftUI
import UIKit

private struct Sauvegarde: Codable {
    var offres: [String: Suivi] = [:]
    var ents: [String: Suivi] = [:]
    var urlMaj: String?
    var cvNom: String?
}

@MainActor
final class AppStore: ObservableObject {
    static let urlParDefaut = "https://raw.githubusercontent.com/Sahdim/MyJobMeca/main/donnees/offres.json"

    @Published var data = DataFile()
    @Published var offres: [String: Suivi] = [:]
    @Published var ents: [String: Suivi] = [:]
    @Published var urlMaj: String = AppStore.urlParDefaut
    @Published var cvNom: String?
    @Published var chargement = false
    @Published var message: String?

    // Candidature en cours (ouverture dans l'appli, puis question au retour)
    @Published var pageCandidature: PageCandidature?
    @Published var question: Offre?
    @Published var mail: MailCandidature?

    private let dossier = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    private var fichierSuivi: URL { dossier.appendingPathComponent("suivi.json") }
    private var fichierCache: URL { dossier.appendingPathComponent("offres-cache.json") }
    var fichierCV: URL { dossier.appendingPathComponent("CV.pdf") }

    init() {
        if let d = try? Data(contentsOf: fichierSuivi), let s = try? JSONDecoder().decode(Sauvegarde.self, from: d) {
            offres = s.offres
            ents = s.ents
            if let u = s.urlMaj, !u.isEmpty { urlMaj = u }
            cvNom = FileManager.default.fileExists(atPath: fichierCV.path) ? (s.cvNom ?? "CV.pdf") : nil
        }
        if let d = try? Data(contentsOf: fichierCache), let f = try? JSONDecoder().decode(DataFile.self, from: d), !f.offres.isEmpty {
            data = f
        } else if let u = Bundle.main.url(forResource: "offres", withExtension: "json"),
                  let d = try? Data(contentsOf: u), let f = try? JSONDecoder().decode(DataFile.self, from: d) {
            data = f
        }
    }

    // MARK: Données

    func actualiser(manuel: Bool = false) async {
        guard !chargement else { return }
        chargement = true
        defer { chargement = false }
        let base = urlMaj.trimmingCharacters(in: .whitespaces).isEmpty ? AppStore.urlParDefaut : urlMaj
        guard var comp = URLComponents(string: base) else { return }
        comp.queryItems = (comp.queryItems ?? []) + [URLQueryItem(name: "t", value: String(Int(Date().timeIntervalSince1970)))]
        guard let url = comp.url else { return }
        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        req.timeoutInterval = 20
        do {
            let (d, r) = try await URLSession.shared.data(for: req)
            if let h = r as? HTTPURLResponse, h.statusCode != 200 { throw URLError(.badServerResponse) }
            let f = try JSONDecoder().decode(DataFile.self, from: d)
            let avant = Set(data.offres.map { $0.id })
            data = f
            try? d.write(to: fichierCache)
            let nouvelles = f.offres.filter { !avant.contains($0.id) }.count
            if manuel || nouvelles > 0 {
                toast(nouvelles > 0 ? "\(nouvelles) nouvelle\(nouvelles > 1 ? "s" : "") offre\(nouvelles > 1 ? "s" : "")" : "Offres à jour")
            }
        } catch {
            if manuel { toast("Pas de connexion : dernières offres affichées") }
        }
    }

    // MARK: Statuts

    func suivi(_ kind: Kind, _ id: String) -> Suivi {
        switch kind {
        case .offre: return offres[id] ?? Suivi(statut: "a_traiter")
        case .ent: return ents[id] ?? Suivi(statut: "a_contacter")
        }
    }

    func statut(_ kind: Kind, _ id: String) -> String { suivi(kind, id).statut }

    func modifier(_ kind: Kind, _ id: String, _ change: (inout Suivi) -> Void) {
        var s = suivi(kind, id)
        change(&s)
        switch kind {
        case .offre: offres[id] = s
        case .ent: ents[id] = s
        }
        enregistrer()
    }

    func changerStatut(_ kind: Kind, _ id: String, _ valeur: String) {
        modifier(kind, id) { s in
            s.statut = valeur
            s.dates[valeur] = Dates.today()
            if kind == .offre && valeur == "postule" && s.dateCandidature == nil { s.dateCandidature = Dates.today() }
        }
        switch valeur {
        case "postule", "envoyee": toast("Candidature notée. Rappel de relance dans 7 jours.")
        case "entretien": toast("Entretien ! Bravo, prépare-toi bien.")
        case "ecartee": toast("Offre écartée")
        default: toast(labelStatut(valeur))
        }
    }

    func lettre(offre o: Offre) -> String { offres[o.id]?.lettre ?? Lettre.pourOffre(o) }
    func lettre(entreprise e: Entreprise) -> String { ents[e.id]?.lettre ?? Lettre.pourEntreprise(e) }

    func enregistrer() {
        let s = Sauvegarde(offres: offres, ents: ents, urlMaj: urlMaj == AppStore.urlParDefaut ? nil : urlMaj, cvNom: cvNom)
        if let d = try? JSONEncoder().encode(s) { try? d.write(to: fichierSuivi, options: .atomic) }
    }

    // MARK: CV

    func importerCV(depuis url: URL) {
        let acces = url.startAccessingSecurityScopedResource()
        defer { if acces { url.stopAccessingSecurityScopedResource() } }
        do {
            let d = try Data(contentsOf: url)
            try d.write(to: fichierCV, options: .atomic)
            cvNom = url.lastPathComponent
            enregistrer()
            toast("CV enregistré dans l'appli")
        } catch {
            toast("Impossible de lire ce fichier")
        }
    }

    // MARK: Listes utiles

    var relances: [(kind: Kind, titre: String, jours: Int)] {
        var out: [(Kind, String, Int)] = []
        for o in data.offres {
            guard let s = offres[o.id], ["postule", "relance"].contains(s.statut) else { continue }
            let j = Dates.daysSince(s.dates[s.statut] ?? s.dateCandidature)
            if j > 7 { out.append((.offre, o.entreprise + " – " + o.poste, j)) }
        }
        for e in data.entreprises {
            guard let s = ents[e.id], ["envoyee", "relancee"].contains(s.statut) else { continue }
            let j = Dates.daysSince(s.dates[s.statut])
            if j > 7 { out.append((.ent, e.nom, j)) }
        }
        return out.sorted { $0.2 > $1.2 }.map { (kind: $0.0, titre: $0.1, jours: $0.2) }
    }

    func trier(_ l: [Offre]) -> [Offre] {
        l.sorted { a, b in
            if a.prio != b.prio { return a.prio < b.prio }
            let pa = publication(a).jours, pb = publication(b).jours
            if pa != pb { return pa < pb }
            return (a.km ?? 99) < (b.km ?? 99)
        }
    }

    // MARK: Message

    func toast(_ t: String) {
        withAnimation(.spring(response: 0.35)) { message = t }
        let courant = t
        Task {
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            if message == courant { withAnimation(.easeOut(duration: 0.25)) { message = nil } }
        }
    }

    // MARK: Postuler

    /// Postuler à une offre : lettre copiée, annonce ouverte DANS l'appli, puis « Candidature envoyée ? » au retour.
    func postuler(_ o: Offre) {
        UIPasteboard.general.string = lettre(offre: o)
        if statut(.offre, o.id) == "a_traiter" {
            modifier(.offre, o.id) { s in s.statut = "a_postuler"; s.dates["a_postuler"] = Dates.today() }
        }
        guard let url = URL(string: o.lien), !o.lien.isEmpty else {
            toast("Pas de lien pour cette offre : ta lettre est copiée")
            return
        }
        pageCandidature = PageCandidature(url: url, offre: o)
    }

    func finCandidature(_ p: PageCandidature) {
        guard let o = p.offre, !["postule", "relance", "entretien"].contains(statut(.offre, o.id)) else { return }
        Task {
            try? await Task.sleep(nanoseconds: 450_000_000)
            question = o
        }
    }

    /// Candidature spontanée : e-mail tout prêt avec la lettre et le CV joint, envoyé sans quitter l'appli.
    func postuler(_ e: Entreprise) {
        let texte = lettre(entreprise: e)
        if let adr = e.email {
            mail = MailCandidature(
                destinataire: adr,
                objet: "Candidature spontanée – Mécanicien service rapide – \(Profil.nom)",
                corps: texte,
                cv: cvNom == nil ? nil : fichierCV,
                entrepriseID: e.id)
        } else if let url = URL(string: e.lienRecrutement), !e.lienRecrutement.isEmpty {
            UIPasteboard.general.string = texte
            pageCandidature = PageCandidature(url: url, offre: nil)
        } else {
            UIPasteboard.general.string = texte
            toast("Pas d'e-mail connu : ta lettre est copiée. Passe sur place avec ton CV !")
        }
    }
}

struct PageCandidature: Identifiable {
    let id = UUID()
    let url: URL
    let offre: Offre?
}

struct MailCandidature: Identifiable {
    let id = UUID()
    let destinataire: String
    let objet: String
    let corps: String
    let cv: URL?
    let entrepriseID: String
}
