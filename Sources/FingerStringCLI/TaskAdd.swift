import ArgumentParser
import FingerStringLib
import Foundation

struct TaskAdd: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "task-add",
		abstract: "Add an task to a list"
	)

	@Argument(help: "Slug of the target list")
	var listSlug: String

	@Argument(help: "Label for the task")
	var label: String

	@Option(help: "Optional note for the task")
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
		
		print("Added task: [\(task.itemHashId)] to \(list.inlineTitle): \(task.label)")
	}
}
