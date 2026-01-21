import ArgumentParser
import FingerStringLib
import Foundation

struct TaskEdit: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "task-edit",
		abstract: "Edit a task's label or note"
	)

	@Argument(help: "Hash ID of the task to edit", completion: .custom({ _, _, prefix in
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

	@Option(help: "New label for the task")
	var label: String?

	@Option(help: "New note for the task")
	var note: String?

	func run() async throws {
		let controller = FingerStringCLI.controller

		guard
			let task = try await controller.getTask(hashID: hashID)
		else {
			print("Task not found with hash '\(hashID)'")
			return
		}

		// Determine which fields to update
		let labelChange: ListController.Change<String>
		if let label {
			labelChange = .change(label)
		} else {
			labelChange = .unchanged
		}
		let noteChange: ListController.Change<String?> = note != nil ? .change(note) : .unchanged

		let updated = try await controller.updateTask(
			id: task.id,
			label: labelChange,
			note: noteChange
		)

		print("Updated task [\(updated.itemHashId)]: \(updated.label)")
	}
}
