import Cocoa
import FinderSync

final class FinderSync: FIFinderSync {
    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForContainer else {
            return nil
        }

        let menu = NSMenu(title: "")
        let item = NSMenuItem(title: "New File...", action: #selector(createNewFile(_:)), keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return menu
    }

    @objc private func createNewFile(_ sender: Any?) {
        guard let directoryURL = FIFinderSyncController.default().targetedURL() else {
            showMessage("MacDown could not determine the current Finder folder.")
            return
        }

        guard let fileName = promptForFileName(), !fileName.isEmpty else {
            return
        }

        guard !fileName.contains("/"), fileName != ".", fileName != ".." else {
            showMessage("Use a plain filename, not a path.")
            return
        }

        let fileURL = directoryURL.appendingPathComponent(fileName, isDirectory: false)
        guard !FileManager.default.fileExists(atPath: fileURL.path) else {
            showMessage("A file with that name already exists.")
            return
        }

        guard FileManager.default.createFile(atPath: fileURL.path, contents: Data(), attributes: nil) else {
            showMessage("The file could not be created there.")
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    private func promptForFileName() -> String? {
        let alert = NSAlert()
        alert.messageText = "New File"
        alert.informativeText = "Enter the filename, including the extension."
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.stringValue = "untitled.md"
        alert.accessoryView = field

        guard alert.runModal() == .alertFirstButtonReturn else {
            return nil
        }
        return field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func showMessage(_ message: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
