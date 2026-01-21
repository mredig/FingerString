import ArgumentParser
import FingerStringLib
import Foundation

struct TaskView: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "task-view",
		abstract: "View details of a task including subtasks"
	)

	@Argument(help: "Hash ID of the task to view", completion: .custom({ _, _, prefix in
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

	@Flag(help: "Show completed subtasks")
	var showCompletedTasks: Bool = false

	func run() async throws {
		let controller = FingerStringCLI.controller

		guard
			let task = try await controller.getTask(hashID: hashID)
		else {
			print("Task not found with hash '\(hashID)'")
			return
		}

		// Print task details
		let lineBuilder = [
			["[", task.isComplete ? "x" : " ", "]"].joined(),
			"[\(task.itemHashId)]",
			"\(task.label)",
			task.note != nil ? "(*)" : nil
		]
		print(lineBuilder.compactMap(\.self).joined(separator: " "))

		if let note = task.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
			print("\n\(note)\n")
		}

		// Print subtasks if they exist
		guard task.firstSubtaskId != nil else { return }
		print("Subtasks:")
		let subtaskStream = try await controller.getAllTasksStream(on: .task(hashID: hashID))
		for try await subtask in subtaskStream {
			try await printItem(subtask.task, indent: "\t")
		}
	}

	private func printItem(
		_ item: TaskItem,
		indent: String = ""
	) async throws {
		guard
			item.isComplete == false || showCompletedTasks
		else { return }

		let lineBuilder = [
			["[", item.isComplete ? "x" : " ", "]"].joined(),
			"[\(item.itemHashId)]",
			"\(item.label)",
			item.note != nil ? "(*)" : nil
		]

		let line = indent + lineBuilder
			.compactMap(\.self)
			.joined(separator: " ")
		print(line)

		guard item.firstSubtaskId != nil else { return }
		let stream = try await FingerStringCLI.controller.getAllTasksStream(on: .task(hashID: item.itemHashId))

		for try await (_, subtask) in stream {
			try await printItem(subtask, indent: indent + "\t")
		}
	}
}
