import ArgumentParser
import FingerStringLib
import Foundation

struct ListCreate: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "list-create",
		abstract: "Create a new list"
	)

	@Argument(help: "Slug for the list (alphanumeric, dots, dashes, underscores)")
	var slug: String

	@Option(help: "Friendly title for the list")
	var title: String?

	@Option(help: "Description for the list")
	var description: String?

	func run() async throws {
		let newList = try await FingerStringCLI.controller.createList(with: slug, friendlyTitle: title, description: description)
		print("Created list '\(newList.slug)'")
		if let title = newList.title {
			print("  Title: \(title)")
		}
	}
}
