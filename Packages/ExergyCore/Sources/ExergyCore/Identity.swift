import Foundation

/// Product identity for Exergy — remaining useful work across every account.
///
/// Thermodynamic namesake: exergy is the remaining work a system can still do.
/// Shannon measures collapse of surprise; Exergy measures how much quota is
/// still available to spend. Same family, different instrument.
public enum ExergyIdentity: Sendable {
    public static let displayName = "Exergy"
    public static let displayNameFR = "Exergie"
    public static let taglineEN = "Remaining useful work"
    public static let taglineFR = "Le travail encore disponible"
    public static let marketingVersion = "1.0.0"
    public static let buildNumber = "1"

    public static let bundlePrefix = "com.lebonhommepharma.exergy"
    public static let iOSBundleID = "com.lebonhommepharma.exergy"
    public static let macBundleID = "com.lebonhommepharma.exergy.mac"
    public static let watchBundleID = "com.lebonhommepharma.exergy.watchkitapp"
    public static let widgetBundleID = "com.lebonhommepharma.exergy.widget"
    public static let complicationBundleID = "com.lebonhommepharma.exergy.watchkitapp.complication"

    public static let iCloudContainer = "iCloud.com.lebonhommepharma.exergy"
    public static let appGroup = "group.com.lebonhommepharma.exergy"
    public static let keychainAccessGroup = "com.lebonhommepharma.exergy"
    public static let urlScheme = "exergy"

    /// Confirmed Apple Developer Team (same as NATURaL). Fill in Xcode; unsigned Simulator builds leave it blank.
    public static let developmentTeam = "ZJLX84G8QV"

    public static let copyright = "2026 Le Bonhomme Pharma"
    public static let supportURL = "https://thebonhomme.com/Exergy/support/"
    public static let privacyURL = "https://thebonhomme.com/Exergy/privacy/"
    public static let marketingURL = "https://thebonhomme.com/Exergy/"

    public static let sku = "exergy-usage-1"
    public static let oauthCallbackHost = "oauth"
    public static let oauthCallbackURL = "exergy://oauth"

    public static var tagline: String {
        L10n.pick(en: taglineEN, fr: taglineFR)
    }

    public static var localizedName: String {
        L10n.pick(en: displayName, fr: displayNameFR)
    }
}
