import ArgumentParser
import FingerStringLib
import Foundation
import SwiftPizzaSnips

struct ItemCompleteToggle: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "item-complete",
		abstract: "Mark or unmark a task as completed"
	)

	@Argument(help: "ID of the task")
	var hashID: String

	@Option(help: "Indicate if the task is completed. Default: `true`", transform: {
		let value = $0.lowercased()

		switch value {
		case "true", "1", "yes", "yeah", "yah", "yep":
			return true
		case "false", "0", "no", "nope", "nah":
			return false
		default:
			throw SimpleError(message: "Invalid input: \($0)")
		}

	})
	var mark: Bool = true

	func run() async throws {
		let controller = FingerStringCLI.controller

		guard
			let task = try await controller.getTask(hashID: hashID)
		else {
			print("Cant find or update task with hash '\(hashID)'")
			return
		}

		let updated = try await controller.updateTask(
			id: task.id,
			isCompleted: .change(mark))

		let completionSlug = updated.isComplete ? "completed" : "incomplete"

		print("Marked task [\(updated.itemHashId)] (\(updated.label.prefix(15))) as \(completionSlug)")
//		guard
//			let list = try await controller.getList(withSlug: listSlug)
//		else {
//			print("no matching list with slug '\(listSlug)'")
//			return
//		}
//
//		let task = try await controller.createTask(label: label, note: note, on: list.id)
//		print("Added item: [\(task.itemId)] \(task.label)")
	}
}
