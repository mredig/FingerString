import ArgumentParser
import FingerStringLib
import Foundation

extension FingerStringCLI {
	struct Options: ParsableArguments {
		@Flag(name: .shortAndLong, help: "Show the version number")
		var version = false
	}
}

@main
struct FingerStringCLI: AsyncParsableCommand {
	nonisolated(unsafe)
	static private var _controller = try! ListController(dbLocation: Constants.defaultDBURL, readOnly: false)
	static var controller: ListController { controllerLock.withLock { _controller } }
	private static let controllerLock = NSLock()

	static let configuration = CommandConfiguration(
		commandName: "fingerstring",
		abstract: "A task list management tool. See README for bash completion setup: https://github.com/mredig/fingerstring#bash-completion-setup",
		subcommands: [
			ListCreate.self,
			ListView.self,
			ListDelete.self,
			ListAll.self,
			TaskAdd.self,
			TaskView.self,
			TaskEdit.self,
			TaskDelete.self,
			TaskCompleteToggle.self,
		])

	@OptionGroup var options: Options
	
	@Option(help: "", transform: { URL(filePath: $0) })
	var customDB: URL?

	func validate() throws {
		if options.version {
			print(version)
			throw ExitCode.success
		}
		
		guard let customDB else { return }

		try Self.controllerLock.withLock {
			Self._controller = try ListController(dbLocation: customDB)
		}
	}
}
