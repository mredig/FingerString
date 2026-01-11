import ArgumentParser
import FingerStringLib
import Foundation

struct ListDelete: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "list-delete",
		abstract: "Delete a list"
	)

	@Argument(help: "Slug of the list to delete")
	var slug: String

	@Flag(help: "Skip confirmation")
	var force: Bool = false

	func run() async throws {
		let controller = FingerStringCLI.controller

		guard
			let list = try await controller.getList(withSlug: slug)
		else {
			print("No list with slug \(slug)")
			return
		}

		if force == false {
			print("Delete list '\(list.inlineTitle)'? [y/N]")
			guard
				let input = readLine(),
				input.lowercased() == "y"
			else {
				print("Cancelled")
				return
			}
		}

		try await controller.deleteList(list.id)

		print("Deleted list '\(list.inlineTitle)'")
	}
}
