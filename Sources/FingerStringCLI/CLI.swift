import ArgumentParser
import FingerStringLib
import Foundation

@main
struct FingerStringCLI: AsyncParsableCommand {
	static let controller = ListController(db: ListController.defaultDB)

	static let configuration = CommandConfiguration(
		commandName: "fingerstring",
		abstract: "A task list management tool",
		subcommands: [
			ListCreate.self,
			ListView.self,
			ListDelete.self,
			ListAll.self,
			TaskAdd.self,
			TaskDelete.self,
			TaskCompleteToggle.self,
		]
	)
}
