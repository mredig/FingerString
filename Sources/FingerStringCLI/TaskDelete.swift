import ArgumentParser
import FingerStringLib
import Foundation

struct TaskDelete: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "task-delete",
		abstract: "Delete a task"
	)

	@Argument(help: "ID of the task to delete")
	var hashID: String

	@Flag(help: "Skip confirmation")
	var force: Bool = false

	func run() async throws {
		let controller = FingerStringCLI.controller

		guard
			let task = try await controller.getTask(hashID: hashID)
		else {
			print("No task with hash \(hashID)")
			return
		}

		if force == false {
			print("Delete \(task.label)? (y/N)")
			guard
				let input = readLine(),
				input.lowercased() == "y"
			else {
				print("Cancelled")
				return
			}
		}

		try await controller.deleteTask(task.id)
		print("Deleted \(task.label) [\(task.itemHashId)]")
	}
}
