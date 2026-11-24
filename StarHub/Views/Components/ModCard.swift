import AppKit
import SwiftUI

/// Un attribut porté par une carte : le glyph, sa teinte s'il en demande une,
/// et ce que dit son infobulle.
struct CardAttribute: Identifiable {
    let id: String
    let systemImage: String
    var tint: Color?
    let help: String
}

/// Carte à vignette de hauteur constante dans la grille.
struct ModCard: View {
    let title: String
    let thumbnailURL: URL?
    /// Le libellé de la pastille posée sur la vignette, ou `nil` quand il n'y
    /// a rien à y poser.
    let installedLabel: String?
    let category: NexusCategory?
    /// Une pastille neutre supplémentaire (« FR »), ou `nil`.
    let neutralBadge: String?
    let endorsements: Int?
    var trailingText: String?
    /// Ce qui tient la place d'une vignette absente. Découvrir garde le
    /// rectangle gris (`false`) — sa vitrine sert des captures Nexus et
    /// l'absence y est l'exception. La grille des mods installés l'allume :
    /// 148 de ses 887 dossiers n'ont aucune image à servir, et une page
    /// entière de rectangles gris se lisait comme un écran qui n'a pas fini
    /// de charger.
    var usesDefaultArtwork: Bool = false
    /// Les attributs du mod — anomalie, note, config gardée par le profil.
    /// La grille des mods installés les montre comme la liste ; Découvrir
    /// n'en a aucun (un mod de la vitrine n'est pas encore chez soi).
    ///
    /// Les attributs ne portent qu'une infobulle. La fiche les détaille.
    var attributes: [CardAttribute] = []
    /// L'état de la page Nexus (A2-T6), ou `nil` quand la dernière reprise
    /// n'a rien observé — Discover n'en a jamais.
    var pageState: NexusPageState? = nil
    /// Passé tel quel à `CategoryBadge`, qui résout le nom localisé.
    let L: (String) -> String
    var action: (() -> Void)? = nil

    var body: some View {
        if let action {
            Button(action: action) { cardLayout }
                .buttonStyle(.plain)
                .focusRing(cornerRadius: AppDesign.Radius.section)
        } else {
            cardLayout
        }
    }

    private var cardLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            thumbnail.clipShape(RoundedRectangle(cornerRadius: AppDesign.Radius.section))
            VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
                HStack(alignment: .top, spacing: 6) {
                    if let pageState {
                        NexusPageBadge(state: pageState, L: L)
                    }
                    Text(title)
                        .font(AppDesign.Font.body(.semibold))
                        .lineLimit(2, reservesSpace: true)
                        .multilineTextAlignment(.leading)
                }
                metaRow
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }

    /// Le rectangle gris couvre l'absence d'image, l'attente et l'échec de
    /// chargement — trois cas qui, sans lui, donneraient trois hauteurs.
    private var thumbnail: some View {
        Rectangle().fill(.quaternary)
            .aspectRatio(AppDesign.Metrics.thumbRatio, contentMode: .fit)
            // L'illustration de l'app (celle de l'écran de lancement), sous
            // la vignette et **voilée** : elle occupe la place, elle ne se
            // fait pas passer pour la capture du mod. Elle n'est dessinée
            // que faute de mieux, et seulement là où l'écran la demande.
            .overlay {
                if usesDefaultArtwork, thumbnailURL == nil, let art = Self.defaultArtwork {
                    Image(nsImage: art)
                        .resizable()
                        .scaledToFill()
                        .opacity(AppDesign.Opacity.strong)
                        .accessibilityHidden(true)
                }
            }
            .overlay {
                // `CachedAsyncImage` garde les images en mémoire : dérouler
                // la vitrine redemanderait sinon les mêmes vignettes au
                // réseau à chaque passage.
                if let thumbnailURL {
                    CachedAsyncImage(url: thumbnailURL)
                }
            }
            .clipped()
            // Sur l'image, pas en bas de pile : c'est ce qu'on cherche en
            // balayant une grille.
            .overlay(alignment: .topTrailing) {
                if let installedLabel {
                    // Pastille **pleine**, pas translucide : posée sur un
                    // matériau, elle se noyait dans les vignettes claires. Du
                    // blanc sur vert tient sur n'importe quelle image, et
                    // l'ombre la décolle du fond.
                    Label(installedLabel, systemImage: "checkmark.circle.fill")
                        .font(AppDesign.Font.caption(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppDesign.Spacing.sm)
                        .padding(.vertical, AppDesign.Spacing.xs)
                        .background(AppDesign.Color.installed, in: Capsule())
                        .shadow(color: .black.opacity(AppDesign.Opacity.strong),
                                radius: AppDesign.Shadow.badge.radius,
                                y: AppDesign.Shadow.badge.y)
                        .padding(AppDesign.Spacing.sm)
                }
            }
    }

    /// L'illustration de l'app, chargée une fois pour toutes les cartes —
    /// c'est la même image que l'écran de lancement (`LaunchSplashWindow`),
    /// déjà copiée dans les ressources du bundle par `build_app.py`.
    private static let defaultArtwork: NSImage? = {
        guard let url = Bundle.main.url(forResource: "nexus_cover_final", withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }()

    private var metaRow: some View {
        HStack(spacing: AppDesign.Spacing.xs + 2) {
            if let category {
                CategoryBadge(category: category, L: L)
            }
            if let neutralBadge {
                NeutralBadge(label: neutralBadge)
                    .fixedSize(horizontal: true, vertical: false)
            }
            attributeIcons
            Spacer(minLength: 0)
            if let trailingText, !trailingText.isEmpty {
                Text(trailingText)
                    .font(AppDesign.Font.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help(trailingText)
            } else if let endorsements {
                Label("\(endorsements)", systemImage: "hand.thumbsup")
                    .font(AppDesign.Font.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(height: AppDesign.Metrics.metaRowHeight)
        .padding(.top, 2)
    }

    private var attributeIcons: some View {
        ForEach(attributes) { attribute in
            Image(systemName: attribute.systemImage)
                .font(AppDesign.Font.iconXS)
                .foregroundStyle(attribute.tint ?? .secondary)
                // La cible qu'exige une infobulle vivante sur macOS.
                .frame(width: 18, height: 18)
                .contentShape(.rect)
                .help(attribute.help)
                .accessibilityLabel(attribute.help)
        }
    }
}
