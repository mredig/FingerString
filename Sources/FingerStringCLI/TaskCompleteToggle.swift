import ArgumentParser
import FingerStringLib
import Foundation
import SwiftPizzaSnips

struct TaskCompleteToggle: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "task-complete",
		abstract: "Mark or unmark a task as completed"
	)

	@Argument(help: "ID of the task", completion: .custom({ _, _, prefix in
		let lcPrefix = prefix.lowercased()
		do {
			let tasks = try await FingerStringCLI.controller.getAllTasks()
			return tasks.map(\.itemHashId).filter { $0.hasPrefix(lcPrefix) }
		} catch {
			print("Error: \(error)")
			return []
		}
	}))
	var hashID: String

	@Option(
		help: "Indicate if the task is completed. Default: `true`",
		completion: .custom({ _, _, prefix in
			let lcPrefix = prefix.lowercased()
			let valid = ["true", "false"]
			let match = valid.first(where: { $0.hasPrefix(lcPrefix) })
			return [match].compactMap(\.self)
		}),
		transform: {
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
	}
}
