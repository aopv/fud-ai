import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear // Keep the transition entirely seamless
        handleShare()
    }
    
    private func handleShare() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else {
            dismissWithError()
            return
        }
        
        // Find the first attachment that conforms to image
        let imageType = UTType.image.identifier
        guard let provider = attachments.first(where: { $0.hasItemConformingToTypeIdentifier(imageType) }) else {
            dismissWithError()
            return
        }
        
        provider.loadItem(forTypeIdentifier: imageType, options: nil) { [weak self] (item, error) in
            guard let self = self else { return }
            
            var imageData: Data? = nil
            
            if let url = item as? URL {
                imageData = try? Data(contentsOf: url)
            } else if let image = item as? UIImage {
                imageData = image.jpegData(compressionQuality: 0.8)
            } else if let data = item as? Data {
                imageData = data
            }
            
            guard let data = imageData else {
                DispatchQueue.main.async {
                    self.dismissWithError()
                }
                return
            }
            
            // Save to shared App Group container using ShareImportManager
            let success = ShareImportManager.saveSharedImage(data)
            if success {
                DispatchQueue.main.async {
                    self.openMainAppAndComplete()
                }
            } else {
                DispatchQueue.main.async {
                    self.dismissWithError()
                }
            }
        }
    }
    private func openMainAppAndComplete() {
        guard let url = URL(string: "fudai://import-share-image") else {
            extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            return
        }
        // extensionContext.open is the official API for extensions to open the containing app.
        // The completion handler fires after the OS hands control to the app, so no arbitrary delay needed.
        extensionContext?.open(url) { [weak self] _ in
            self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }
    
    private func dismissWithError() {
        let alert = UIAlertController(
            title: "Error",
            message: "Unable to process the shared image.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.extensionContext?.cancelRequest(withError: NSError(domain: "ShareError", code: 1, userInfo: nil))
        })
        present(alert, animated: true)
    }
}
