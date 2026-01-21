import ArgumentParser
import FingerStringLib
import Foundation

@main
struct FingerStringCLI: AsyncParsableCommand {
	nonisolated(unsafe)
	static private var _controller = ListController(db: ListController.defaultDB)
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

	@Option(help: "", transform: { URL(filePath: $0) })
	var customDB: URL?

	func validate() throws {
		guard let customDB else { return }

		try Self.controllerLock.withLock {
			Self._controller = try ListController(dbLocation: customDB)
		}
	}
}
