import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Customizes the "blocking" screen that appears when a user tries to open
/// a shielded (blocked) app. Instead of Apple's default Screen Time message,
/// this shows the Unplug Together branding with a garden-themed message.
///
/// This extension is called by iOS whenever a shielded app is opened.

@main
class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    static func main() {}

    // MARK: - App Shield (when opening a blocked app)

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        let appName = application.localizedDisplayName ?? "this app"

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterial,
            backgroundColor: UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0),
            icon: UIImage(systemName: "leaf.fill"),
            title: ShieldConfiguration.Label(
                text: "Time's Up!",
                color: UIColor(red: 1.0, green: 0.42, blue: 0.42, alpha: 1.0) // #FF6B6B
            ),
            subtitle: ShieldConfiguration.Label(
                text: "Your \(appName) limit has been reached.\nAsk your partner to approve more time,\nor put the phone down and grow your garden! 🌱",
                color: UIColor.secondaryLabel
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Ask Partner for More Time",
                color: .white
            ),
            primaryButtonBackgroundColor: UIColor(red: 1.0, green: 0.42, blue: 0.42, alpha: 1.0),
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "Close \(appName)",
                color: UIColor.secondaryLabel
            )
        )
    }

    // MARK: - Web Domain Shield

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        let domainName = webDomain.domain ?? "this site"

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterial,
            backgroundColor: UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0),
            icon: UIImage(systemName: "leaf.fill"),
            title: ShieldConfiguration.Label(
                text: "Time's Up!",
                color: UIColor(red: 1.0, green: 0.42, blue: 0.42, alpha: 1.0)
            ),
            subtitle: ShieldConfiguration.Label(
                text: "Your time on \(domainName) has been reached.\nAsk your partner to approve more time.",
                color: UIColor.secondaryLabel
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Ask Partner",
                color: .white
            ),
            primaryButtonBackgroundColor: UIColor(red: 1.0, green: 0.42, blue: 0.42, alpha: 1.0),
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "Go Back",
                color: UIColor.secondaryLabel
            )
        )
    }

    // MARK: - App Category Shield

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        return configuration(shielding: application)
    }
}
