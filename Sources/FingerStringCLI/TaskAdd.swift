import ArgumentParser
import FingerStringLib
import Foundation

struct TaskAdd: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "task-add",
		abstract: "Add an task to a list"
	)

	@Argument(help: "Slug of the target list or hash id of the parent task", completion: .custom({ _, _, prefix in
		do {
			let lcPrefix = prefix.lowercased()
			let lists = try await FingerStringCLI.controller.getAllLists()
			guard lists.isOccupied else {
				return []
			}

			let matchingLists = lists.map(\.slug).filter { $0.hasPrefix(lcPrefix) }
			guard matchingLists.isEmpty else { return matchingLists }
			// no matching lists, it might be a hash id

			let tasks = try await FingerStringCLI.controller.getAllTasks()
			return tasks.map(\.itemHashId).filter { $0.hasPrefix(lcPrefix) }
		} catch {
			print("Error: \(error)")
			return []
		}
	}))
	var query: String

	@Argument(help: "Label for the task")
	var label: String

	@Option(help: "Optional note for the task")
	var note: String?

	func run() async throws {
		let controller = FingerStringCLI.controller

		let parent: ListController.TaskParent
		let successTitle: String
		if query.count == Constants.hashIDLength {
			if let parentTask = try await controller.getTask(hashID: query) {
				parent = .task(hashID: query)
				successTitle = "[\(parentTask.itemHashId)] \(parentTask.label)"
			} else if let list = try await controller.getList(withSlug: query) {
				parent = .list(list.id)
				successTitle = list.inlineTitle
			} else {
				print("No matching task with id or list slug '\(query)'")
				return
			}
		} else {
			guard
				let list = try await controller.getList(withSlug: query)
			else {
				print("no matching list with slug '\(query)'")
				return
			}
			successTitle = list.inlineTitle
			parent = .list(list.id)
		}


		let task = try await controller.createTask(label: label, note: note, on: parent)
		
		print("Added task: [\(task.itemHashId)] to \(successTitle): \(task.label)")
	}
}
