import SwiftUI
import SafariServices
import MessageUI

// MARK: - Couleurs (noir profond, graphite, accents iOS)

extension Color {
    static let fond = Color.black
    static let carte = Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255)
    static let carte2 = Color(red: 44 / 255, green: 44 / 255, blue: 46 / 255)
    static let texte2 = Color.white.opacity(0.72)
    static let texte3 = Color.white.opacity(0.45)
    static let accent = Color(red: 1.0, green: 159 / 255, blue: 10 / 255)
    static let bleu = Color(red: 10 / 255, green: 132 / 255, blue: 1.0)
    static let vert = Color(red: 48 / 255, green: 209 / 255, blue: 88 / 255)
    static let jaune = Color(red: 1.0, green: 214 / 255, blue: 10 / 255)
    static let rouge = Color(red: 1.0, green: 69 / 255, blue: 58 / 255)
    static let ciel = Color(red: 100 / 255, green: 210 / 255, blue: 1.0)
}

func couleurStatut(_ s: String) -> Color {
    switch s {
    case "a_postuler": return .accent
    case "postule", "envoyee": return .ciel
    case "relance", "relancee": return .jaune
    case "entretien", "reponse": return .vert
    case "refus": return .rouge
    default: return .white
    }
}

// MARK: - Boutons

struct BoutonBlanc: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Color.white.opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct BoutonGris: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Color.carte2.opacity(configuration.isPressed ? 0.7 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Petits éléments

struct Pastille: View {
    let texte: String
    var icone: String? = nil
    var couleur: Color = .texte2
    var fond: Color = .carte2
    var body: some View {
        HStack(spacing: 5) {
            if let icone { Image(systemName: icone).font(.system(size: 11, weight: .semibold)) }
            Text(texte).font(.system(size: 13, weight: .semibold)).lineLimit(1)
        }
        .foregroundColor(couleur)
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(fond)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct BadgePrio: View {
    let prio: Int
    var body: some View {
        Text("PRIO \(prio)")
            .font(.system(size: 11, weight: .heavy))
            .tracking(0.4)
            .foregroundColor(prio == 1 ? .black : (prio == 2 ? .white : .texte3))
            .padding(.horizontal, 7).padding(.vertical, 4)
            .background(prio == 1 ? Color.white : (prio == 2 ? Color.carte2 : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(prio == 3 ? Color.texte3 : .clear, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

struct TitreSection: View {
    let titre: String
    var sous: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(titre).font(.system(size: 22, weight: .bold)).foregroundColor(.white)
            Spacer()
            if let sous { Text(sous).font(.system(size: 13)).foregroundColor(.texte3) }
        }
    }
}

/// Mise en page qui passe à la ligne (étiquettes, compétences)
struct Flux: Layout {
    var espace: CGFloat = 6
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let largeur = proposal.width ?? 320
        var x: CGFloat = 0, y: CGFloat = 0, ligne: CGFloat = 0, maxX: CGFloat = 0
        for v in subviews {
            let t = v.sizeThatFits(.unspecified)
            if x + t.width > largeur && x > 0 { x = 0; y += ligne + espace; ligne = 0 }
            x += t.width + espace
            maxX = max(maxX, x - espace)
            ligne = max(ligne, t.height)
        }
        return CGSize(width: proposal.width ?? maxX, height: y + ligne)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, ligne: CGFloat = 0
        for v in subviews {
            let t = v.sizeThatFits(.unspecified)
            if x + t.width > bounds.maxX && x > bounds.minX { x = bounds.minX; y += ligne + espace; ligne = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(t))
            x += t.width + espace
            ligne = max(ligne, t.height)
        }
    }
}

/// Menu de statut en pastille
struct MenuStatut: View {
    @EnvironmentObject var store: AppStore
    let kind: Kind
    let id: String
    var body: some View {
        let actuel = store.statut(kind, id)
        Menu {
            ForEach(kind == .offre ? STATUTS_OFFRE : STATUTS_ENT) { s in
                Button {
                    store.changerStatut(kind, id, s.id)
                } label: {
                    if s.id == actuel { Label(s.label, systemImage: "checkmark") } else { Text(s.label) }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Circle().fill(couleurStatut(actuel)).frame(width: 7, height: 7)
                Text(labelStatut(actuel)).font(.system(size: 14, weight: .semibold))
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.carte2)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Page web DANS l'appli (pour postuler sans quitter Job Méca)

struct PageWeb: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let c = SFSafariViewController.Configuration()
        c.entersReaderIfAvailable = false
        c.barCollapsingEnabled = true
        let vc = SFSafariViewController(url: url, configuration: c)
        vc.preferredControlTintColor = .white
        vc.preferredBarTintColor = .black
        vc.dismissButtonStyle = .done
        return vc
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}

// MARK: - E-mail de candidature envoyé depuis l'appli

struct FenetreMail: UIViewControllerRepresentable {
    let mail: MailCandidature
    let fin: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(fin: fin) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients([mail.destinataire])
        vc.setSubject(mail.objet)
        vc.setMessageBody(mail.corps, isHTML: false)
        if let cv = mail.cv, let d = try? Data(contentsOf: cv) {
            vc.addAttachmentData(d, mimeType: "application/pdf", fileName: "CV \(Profil.nom).pdf")
        }
        return vc
    }
    func updateUIViewController(_ vc: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let fin: (Bool) -> Void
        init(fin: @escaping (Bool) -> Void) { self.fin = fin }
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true)
            fin(result == .sent)
        }
    }
}
