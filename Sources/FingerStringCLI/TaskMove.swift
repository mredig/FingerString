import ArgumentParser
import FingerStringLib
import Foundation

struct TaskMove: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "task-move",
		abstract: "Move a task (and its subtasks) to a list or under another task"
	)

	@Argument(help: "Hash ID of the task to move", completion: .custom({ _, _, prefix in
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

	@Argument(help: "Slug of the destination list or hash id of the new parent task", completion: .custom({ _, _, prefix in
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

	func run() async throws {
		let controller = FingerStringCLI.controller

		guard
			let task = try await controller.getTask(hashID: hashID)
		else {
			print("No task with hash \(hashID)")
			return
		}

		let parent: ListController.TaskParent
		let destinationTitle: String
		if query.count == Constants.hashIDLength {
			if let parentTask = try await controller.getTask(hashID: query) {
				parent = .task(hashID: query)
				destinationTitle = "[\(parentTask.itemHashId)] \(parentTask.label)"
			} else if let list = try await controller.getList(withSlug: query) {
				parent = .list(list.id)
				destinationTitle = list.inlineTitle
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
			destinationTitle = list.inlineTitle
			parent = .list(list.id)
		}

		do {
			try await controller.moveTask(task.id, to: parent)
		} catch let error as ListController.MoveError {
			print("Cannot move task: \(error)")
			return
		}

		print("Moved [\(task.itemHashId)] \(task.label) to \(destinationTitle)")
	}
}
