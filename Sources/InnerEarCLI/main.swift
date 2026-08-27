import Foundation

let exitCode = CLIRunner.run(arguments: Array(CommandLine.arguments.dropFirst()))
exit(exitCode)
