import Foundation
import SwiftUI

// MARK: - Dates

enum Dates {
    static let iso: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Paris")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    static let moisCourt = ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."]
    static let moisLong = ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre"]

    static func today() -> String { iso.string(from: Date()) }

    static func parse(_ s: String) -> Date? {
        guard s.count >= 10 else { return nil }
        return iso.date(from: String(s.prefix(10)))
    }

    static func daysSince(_ s: String?) -> Int {
        guard let s, let d = parse(s) else { return 0 }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Paris") ?? .current
        return cal.dateComponents([.day], from: cal.startOfDay(for: d), to: cal.startOfDay(for: Date())).day ?? 0
    }

    static func court(_ s: String?) -> String {
        guard let s, let d = parse(s) else { return s ?? "" }
        let c = Calendar(identifier: .gregorian).dateComponents([.day, .month, .year], from: d)
        return "\(c.day ?? 1) \(moisCourt[(c.month ?? 1) - 1]) \(c.year ?? 2026)"
    }

    static func longue(_ d: Date = Date()) -> String {
        let c = Calendar(identifier: .gregorian).dateComponents([.day, .month, .year], from: d)
        return "\(c.day ?? 1) \(moisLong[(c.month ?? 1) - 1]) \(c.year ?? 2026)"
    }

    /// "2026-11-23T13:50:00" -> "23 novembre à 13h50"
    static func maj(_ s: String?) -> String {
        guard let s, s.count >= 16, let d = parse(s) else { return "date inconnue" }
        let c = Calendar(identifier: .gregorian).dateComponents([.day, .month], from: d)
        let heure = s.dropFirst(11).prefix(5).replacingOccurrences(of: ":", with: "h")
        return "\(c.day ?? 1) \(moisLong[(c.month ?? 1) - 1]) à \(heure)"
    }
}

struct Publication {
    let texte: String
    let nouveau: Bool
    let connue: Bool
    let jours: Int
}

func publication(_ o: Offre) -> Publication {
    let v = o.publiee.trimmingCharacters(in: .whitespaces)
    if Dates.parse(v) != nil {
        let j = Dates.daysSince(v)
        let t: String
        switch j {
        case ...0: t = "Publiée aujourd'hui"
        case 1: t = "Publiée hier"
        case 2...6: t = "Publiée il y a \(j) jours"
        default: t = "Publiée le \(Dates.court(v))"
        }
        return Publication(texte: t, nouveau: j <= 2, connue: true, jours: j)
    }
    let parts = v.split(separator: "-")
    if parts.count == 2, let y = Int(parts[0]), let m = Int(parts[1]), (1...12).contains(m) {
        return Publication(texte: "Publiée en \(Dates.moisLong[m - 1]) \(y)", nouveau: false, connue: true, jours: 99)
    }
    return Publication(texte: "Date de publication inconnue", nouveau: false, connue: false, jours: 999)
}

func distance(_ km: Double?) -> String {
    guard let km else { return "" }
    return km == 0 ? "sur place" : "\(Int(km)) km"
}

// MARK: - Niveau d'expérience demandé, comparé au profil

enum NiveauXP { case ok, proche, eleve, inconnu }

private func has(_ pattern: String, _ text: String) -> Bool {
    text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
}

func niveauXP(_ txt: String) -> (NiveauXP, String) {
    let t = txt.lowercased()
    if t.trimmingCharacters(in: .whitespaces).isEmpty { return (.inconnu, "Expérience") }
    if has("débutant|debutant|débuts|sans exp|aucune exp|première exp|premiere exp|cap suffisant|accepté|junior|formation", t) { return (.ok, "Bon pour toi") }
    if has("([3-9]|[0-9][0-9])\\s*ans|confirmé|expérimenté|senior", t) { return (.eleve, "Expérience élevée") }
    if has("1 à 2 ans|1 an|un an|appréci|souhait|significative|à vérifier", t) { return (.proche, "Proche de ton profil") }
    if has("cap|bep|bac", t) && !has("[0-9]\\s*ans", t) { return (.ok, "Bon pour toi") }
    if has("2 ans", t) { return (.proche, "Proche de ton profil") }
    return (.inconnu, "Expérience")
}

// MARK: - Conseils du suivi

func conseil(kind: Kind, statut: String, jours: Int) -> (alerte: Bool, texte: String) {
    switch (kind, statut) {
    case (.offre, "a_postuler"): return (false, "Envoie ta candidature aujourd'hui : les offres partent vite.")
    case (.offre, "postule"):
        return jours > 7
            ? (true, "Plus de 7 jours sans réponse : appelle et demande le chef d'atelier. « Bonjour, j'ai postulé il y a une semaine pour le poste de mécanicien, je voulais savoir si ma candidature avait été vue. »")
            : (false, "Laisse 7 jours. Si pas de nouvelles, relance par téléphone : l'appli te le rappellera.")
    case (.offre, "relance"):
        return jours > 7
            ? (true, "Toujours rien : passe directement au garage avec ton CV imprimé, en tenue propre, entre 9 h et 11 h.")
            : (false, "Relance faite. Sans réponse sous une semaine, passe sur place avec ton CV.")
    case (.offre, "entretien"): return (false, "Parle de tes 3 distributions seul (1.7 CDTI, 1.4 HDi, 3.0 V6) et de ton autonomie en service rapide. Viens avec ton CV et ton diplôme.")
    case (.offre, "refus"): return (false, "Pas grave. Demande poliment ce qui a manqué, et propose de repasser dans quelques mois.")
    case (.ent, "envoyee"):
        return jours > 7 ? (true, "Plus de 7 jours : passe sur place et demande à voir le chef d'atelier 2 minutes.") : (false, "Laisse 7 jours avant de relancer.")
    case (.ent, "relancee"): return (false, "Note le nom de la personne rencontrée, et redonne des nouvelles dans 2 à 3 semaines.")
    case (.ent, "reponse"): return (false, "Super ! Note la suite (entretien, essai, date) dans tes notes.")
    default: return (false, "")
    }
}

// MARK: - Lettre de motivation (écrite dans l'appli, sans internet)

enum Lettre {
    static let marques = ["Renault", "Peugeot", "Citroën", "Citroen", "Toyota", "Lexus", "BMW", "MINI", "Mercedes", "Audi", "Volkswagen", "Ford", "Kia", "Hyundai", "Dacia", "Nissan", "Opel", "Fiat", "Skoda", "Seat", "Cupra", "Volvo", "Jaguar", "Tesla", "Mazda", "Suzuki", "Honda", "Jeep", "Porsche", "MG", "BYD"]
    static let agences = "adecco|randstad|ad[ée]quat|proman|ras int[ée]rim|temporis|camo|capactuel|manpower|start people|synergie|crit|actual|partnaire|samsic|int[ée]rim"

    static func nomPropre(_ n: String) -> String {
        n.replacingOccurrences(of: "\\s*\\(.*?\\)\\s*", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    static func marque(in text: String) -> String {
        let t = " " + text + " "
        for m in marques {
            let p = "[^A-Za-zÀ-ÿ]" + NSRegularExpression.escapedPattern(for: m) + "[^A-Za-zÀ-ÿ]"
            if t.range(of: p, options: [.regularExpression, .caseInsensitive]) != nil { return m == "Citroen" ? "Citroën" : m }
        }
        return ""
    }

    static func objet(offre o: Offre) -> String {
        "Candidature – " + poste(o.poste) + " – " + Profil.nom
    }

    static func poste(_ p: String) -> String {
        let s = p.replacingOccurrences(of: "\\s*[HF]/[HF]\\s*", with: " ", options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: .whitespaces)
        return s.isEmpty ? "Mécanicien automobile" : s
    }

    static func pourOffre(_ o: Offre) -> String {
        generer(spont: false, nomBrut: o.entreprise, type: o.type, ville: o.ville, poste: o.poste, note: o.note, marqueTxt: "", adresse: "")
    }

    static func pourEntreprise(_ e: Entreprise) -> String {
        generer(spont: true, nomBrut: e.nom, type: e.type, ville: e.ville, poste: "", note: e.note, marqueTxt: e.marque, adresse: e.adresse)
    }

    private static func generer(spont: Bool, nomBrut: String, type: String, ville villeBrute: String, poste posteBrut: String, note: String, marqueTxt: String, adresse: String) -> String {
        let nom = nomPropre(nomBrut)
        let typeTxt = (type + " " + nomBrut).lowercased()
        let agence = !spont && has(agences, nomBrut)
        var client = ""
        if agence, let r = nomBrut.range(of: "\\((.*?)\\)", options: .regularExpression) {
            client = String(nomBrut[r]).trimmingCharacters(in: CharacterSet(charactersIn: "()"))
                .replacingOccurrences(of: "^clients?\\s+", with: "", options: [.regularExpression, .caseInsensitive])
        }
        let contexte = typeTxt + " " + client.lowercased()
        let concession = has("concession|constructeur", contexte)
        let centre = has("centre|feu vert|norauto|speedy|midas|euromaster|point s|vulco|entretien", contexte)
        let marque = Lettre.marque(in: marqueTxt + " " + nomBrut + " " + note)
        let posteTxt = spont ? "mécanicien automobile en service rapide" : poste(posteBrut)
        let posteMin = posteTxt.prefix(1).lowercased() + posteTxt.dropFirst()
        let ville = villeBrute.split(separator: "/").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        let proche = has("villenave|b[èe]gles|cadaujac|bouliac|floirac", ville)
        let deVille = ville.isEmpty ? "" : " de \(ville)"
        let aVille = ville.isEmpty ? "" : " à \(ville)"

        var L: [String] = [Profil.nom, Profil.ville, Profil.tel, Profil.mail, ""]
        if spont {
            L.append([nom, adresse, ville].filter { !$0.isEmpty }.joined(separator: "\n"))
        } else {
            L.append([nom, ville].filter { !$0.isEmpty }.joined(separator: "\n"))
        }
        L += ["", "\(Profil.ville), le \(Dates.longue())", ""]
        L.append(spont ? "Objet : candidature spontanée – mécanicien automobile (service rapide)" : "Objet : candidature au poste de \(posteMin)")
        L += ["", "Madame, Monsieur,", ""]

        if spont {
            if concession && !marque.isEmpty {
                L.append("Je me permets de vous proposer ma candidature pour un poste de mécanicien en service rapide au sein de votre concession \(marque)\(deVille). J'habite à \(Profil.ville)\(proche ? ", à quelques minutes de chez vous" : "") et je cherche un atelier où m'investir sur la durée : une concession est pour moi le meilleur endroit pour progresser.")
            } else if centre {
                L.append("Je me permets de vous proposer ma candidature pour un poste de mécanicien en service rapide dans votre centre\(deVille). J'habite à \(Profil.ville)\(proche ? ", tout près" : "") et je suis disponible tout de suite.")
            } else {
                L.append("Je me permets de vous proposer ma candidature pour un poste de mécanicien automobile dans votre garage\(deVille). J'habite à \(Profil.ville)\(proche ? ", tout près" : "") et je suis disponible tout de suite.")
            }
        } else if agence {
            L.append("Votre offre de \(posteMin)\(client.isEmpty ? "" : " pour votre client (\(client))")\(aVille) a retenu toute mon attention. Titulaire d'un CAP Maintenance des véhicules, autonome en service rapide et disponible immédiatement, je pense correspondre à ce que recherche votre client.")
        } else if concession {
            L.append("Votre offre de \(posteMin) chez \(nom)\(aVille) a retenu toute mon attention. Travailler en concession\(marque.isEmpty ? "" : " sur des véhicules \(marque)"), avec des méthodes et des outils constructeur, c'est exactement l'environnement dans lequel je veux progresser.")
        } else if centre {
            L.append("Votre offre de \(posteMin) chez \(nom)\(aVille) a retenu toute mon attention. Le service rapide, c'est un travail que je connais et que j'aime : des interventions bien faites, dans les temps, avec un client qui repart rassuré.")
        } else {
            L.append("Votre offre de \(posteMin) chez \(nom)\(aVille) a retenu toute mon attention. Je suis titulaire d'un CAP Maintenance des véhicules et je suis disponible immédiatement.")
        }
        L.append("")
        L.append("J'ai commencé la mécanique par passion, sur mes propres véhicules, pendant un an et demi : vidanges, train avant, disques et plaquettes, berceau, kit embrayage. J'ai ensuite validé mon CAP Maintenance des véhicules en apprentissage dans un garage spécialisé Range Rover et BMW. Aux côtés du mécanicien, j'ai participé à des distributions, des décaissages, des déposes moteur, des embrayages et des interventions sur boîte de vitesses. En fin de formation, j'étais autonome sur le décaissage et la dépose moteur, et j'ai réalisé seul trois distributions (1.7 CDTI, 1.4 HDi et 3.0 V6).")
        L.append("")
        if centre && !concession {
            L.append("Aujourd'hui, je suis autonome en service rapide (vidange, filtres, freinage, pneus, contrôles) et je sais travailler proprement et efficacement quand l'atelier est chargé. Je suis à l'aise avec le contact client et j'ai envie d'apprendre encore, notamment en diagnostic.")
        } else if concession {
            L.append("Aujourd'hui, je suis autonome en service rapide et je souhaite évoluer vers la grosse mécanique et le diagnostic. Rejoindre \(agence ? "une concession" : "votre équipe"), avec ses formations et son suivi, me permettrait de progresser tout en étant utile dès le premier jour sur l'entretien courant.")
        } else {
            L.append("Aujourd'hui, je suis autonome en service rapide et je souhaite évoluer vers la grosse mécanique et le diagnostic. J'apprends vite, je suis rigoureux et j'aime le travail bien fait.")
        }
        L += ["", "Motivé, ponctuel et disponible immédiatement, je suis titulaire du permis B. Je serais heureux de vous rencontrer pour un entretien, ou de faire un essai en atelier pour vous montrer ce que je sais faire.", ""]
        L += ["Je vous prie d'agréer, Madame, Monsieur, mes salutations distinguées.", "", Profil.nom]
        return L.joined(separator: "\n")
    }
}
