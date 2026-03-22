import Dispatch
import Foundation
import OpenNotchCore

@MainActor
final class YabaiRuntimeMonitor {
    private let stateURL: URL
    private let directoryURL: URL

    private var fileDescriptor: CInt = -1
    private var source: DispatchSourceFileSystemObject?
    private var reloadWorkItem: DispatchWorkItem?

    var onStateChange: ((YabaiLiveState?) -> Void)?

    init(stateURL: URL) {
        self.stateURL = stateURL
        directoryURL = stateURL.deletingLastPathComponent()
    }

    func start() {
        stop()

        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        loadCurrentState()

        fileDescriptor = open(directoryURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete, .extend],
            queue: DispatchQueue.main
        )

        source.setEventHandler { [weak self] in
            self?.scheduleReload()
        }

        source.setCancelHandler { [fileDescriptor] in
            if fileDescriptor >= 0 {
                close(fileDescriptor)
            }
        }

        self.source = source
        source.resume()
    }

    func stop() {
        reloadWorkItem?.cancel()
        reloadWorkItem = nil

        source?.cancel()
        source = nil
        fileDescriptor = -1
    }

    private func scheduleReload() {
        reloadWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.loadCurrentState()
        }

        reloadWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01, execute: workItem)
    }

    private func loadCurrentState() {
        let state = try? YabaiLiveStateStore.load(from: stateURL)

        Task { @MainActor [weak self] in
            self?.onStateChange?(state ?? nil)
        }
    }
}
