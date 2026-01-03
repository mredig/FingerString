import ArgumentParser
import FingerStringLib
import Foundation

struct ItemAdd: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "item-add",
		abstract: "Add an item to a list"
	)

	@Argument(help: "Slug of the target list")
	var listSlug: String

	@Argument(help: "Label for the item")
	var label: String

	@Option(help: "Optional note for the item")
	var note: String?

	func run() async throws {
		let controller = FingerStringCLI.controller

		guard
			let list = try await controller.getList(withSlug: listSlug)
		else {
			print("no matching list with slug '\(listSlug)'")
			return
		}

		let task = try await controller.createTask(label: label, note: note, on: list.id)
		print("Added item: [\(task.itemId)] \(task.label)")
	}
}
