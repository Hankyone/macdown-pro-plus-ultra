import Cocoa
import FinderSync

final class FinderSync: FIFinderSync {
    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
        NSLog("MacDownFinderExtension loaded")
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForContainer else {
            return nil
        }

        let menu = NSMenu(title: "")
        let item = NSMenuItem(title: "New File", action: #selector(createNewFile(_:)), keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return menu
    }

    @objc func createNewFile(_ sender: Any?) {
        NSLog("MacDownFinderExtension createNewFile invoked")

        guard let directoryURL = FIFinderSyncController.default().targetedURL() else {
            NSLog("MacDownFinderExtension missing targetedURL")
            return
        }

        let fileName = nextAvailableFileName(in: directoryURL)
        let fileURL = directoryURL.appendingPathComponent(fileName, isDirectory: false)
        NSLog("MacDownFinderExtension creating %@", fileURL.path)

        guard FileManager.default.createFile(atPath: fileURL.path, contents: Data(), attributes: nil) else {
            NSLog("MacDownFinderExtension failed to create %@", fileURL.path)
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    private func nextAvailableFileName(in directoryURL: URL) -> String {
        let base = "untitled"
        var candidate = base
        var index = 2

        while FileManager.default.fileExists(atPath: directoryURL.appendingPathComponent(candidate).path) {
            candidate = "\(base) \(index)"
            index += 1
        }

        return candidate
    }
}
