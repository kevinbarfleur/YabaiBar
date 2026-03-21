import Foundation
import OpenNotchCore

if let exitCode = YabaiSignalHandler.runIfNeeded(arguments: CommandLine.arguments) {
    exit(exitCode)
}

fputs("YabaiBarSignalHelper must be invoked with --signal <event>.\n", stderr)
exit(1)
