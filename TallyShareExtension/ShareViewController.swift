import UIKit
import SwiftUI
import UniformTypeIdentifiers

/// Principal class for the share extension. Pulls the shared text out of the
/// extension context and hands it to a SwiftUI confirmation screen.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        loadSharedText { [weak self] text in
            DispatchQueue.main.async { self?.showUI(with: text) }
        }
    }

    private func showUI(with text: String) {
        let root = ShareConfirmView(
            initialText: text,
            onClose: { [weak self] in self?.complete() }
        )
        let host = UIHostingController(rootView: root)
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.view.backgroundColor = .clear
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }

    private func complete() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func loadSharedText(completion: @escaping (String) -> Void) {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem else {
            completion(""); return
        }

        // Prefer the attributed body text if Messages provided it directly.
        if let text = item.attributedContentText?.string, !text.isEmpty {
            completion(text); return
        }

        let providers = item.attachments ?? []
        let textType = UTType.plainText.identifier
        let urlType = UTType.url.identifier

        for provider in providers where provider.hasItemConformingToTypeIdentifier(textType) {
            provider.loadItem(forTypeIdentifier: textType, options: nil) { data, _ in
                completion((data as? String) ?? "")
            }
            return
        }
        for provider in providers where provider.hasItemConformingToTypeIdentifier(urlType) {
            provider.loadItem(forTypeIdentifier: urlType, options: nil) { data, _ in
                completion((data as? URL)?.absoluteString ?? "")
            }
            return
        }
        completion("")
    }
}
