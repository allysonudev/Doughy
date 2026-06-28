//
//  ShareViewController.swift
//  Doughy Share Extension
//

import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let statusLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private var didStart = false

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didStart else { return }
        didStart = true

        Task { @MainActor in
            await openSharedRecipeURL()
        }
    }

    private func configureView() {
        view.backgroundColor = .systemBackground

        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.text = NSLocalizedString("share_extension.opening", comment: "Status while the share extension opens the main Doughy app")
        statusLabel.font = .preferredFont(forTextStyle: .headline)
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        closeButton.setTitle(NSLocalizedString("action.cancel", comment: "Cancel button"), for: .normal)
        closeButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        closeButton.isHidden = true
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [spinner, statusLabel, closeButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.layoutMarginsGuide.trailingAnchor),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            statusLabel.widthAnchor.constraint(lessThanOrEqualTo: view.layoutMarginsGuide.widthAnchor),
        ])
    }

    @MainActor
    private func openSharedRecipeURL() async {
        guard let sharedURL = await firstSharedURL() else {
            showError(NSLocalizedString("share_extension.no_url", comment: "Shown when the share extension cannot find a URL"))
            return
        }

        guard let deepLink = deepLink(for: sharedURL) else {
            showError(NSLocalizedString("share_extension.no_url", comment: "Shown when the share extension cannot find a URL"))
            return
        }

        guard let extensionContext else {
            showError(NSLocalizedString("share_extension.open_failed", comment: "Shown when the share extension cannot open the main app"))
            return
        }

        let success = await extensionContext.open(deepLink)
        if success {
            extensionContext.completeRequest(returningItems: [], completionHandler: nil)
        } else {
            showError(NSLocalizedString("share_extension.open_failed", comment: "Shown when the share extension cannot open the main app"))
        }
    }

    private func firstSharedURL() async -> URL? {
        let attachments = extensionContext?.inputItems
            .compactMap { $0 as? NSExtensionItem }
            .flatMap { $0.attachments ?? [] } ?? []

        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
               let url = await loadURL(from: provider, typeIdentifier: UTType.url.identifier) {
                return url
            }
        }

        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
               let url = await loadURL(from: provider, typeIdentifier: UTType.plainText.identifier) {
                return url
            }
        }

        return nil
    }

    private func loadURL(from provider: NSItemProvider, typeIdentifier: String) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                continuation.resume(returning: Self.url(from: item))
            }
        }
    }

    private static func url(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }
        if let url = item as? NSURL {
            return url as URL
        }
        if let string = item as? String {
            return URL(string: string)
        }
        if let data = item as? Data,
           let string = String(data: data, encoding: .utf8) {
            return URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    private func deepLink(for recipeURL: URL) -> URL? {
        var components = URLComponents()
        components.scheme = "doughy"
        components.host = "import"
        components.queryItems = [
            URLQueryItem(name: "url", value: recipeURL.absoluteString)
        ]
        return components.url
    }

    @MainActor
    private func showError(_ message: String) {
        spinner.stopAnimating()
        statusLabel.text = message
        closeButton.isHidden = false
    }

    @objc private func cancel() {
        extensionContext?.cancelRequest(withError: CocoaError(.userCancelled))
    }
}
