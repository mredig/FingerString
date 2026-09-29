@testable import FingerStringLib

extension ListController {
	@discardableResult
	func makeList(_ slug: String = "list") async throws -> TaskList {
		try await createList(with: slug, friendlyTitle: nil, description: nil)
	}

	@discardableResult
	func addTask(_ label: String, to parent: TaskParent, note: String? = nil) async throws -> TaskItem {
		try await createTask(label: label, note: note, on: parent)
	}

	func labels(on parent: TaskParent) async throws -> [String] {
		try await getAllTasks(on: parent).map(\.label)
	}
}

extension ListController {
	/// Checks the linked-list invariants for the children of `parent`, returning a description of each violation:
	/// - the head pointer leads to a chain with no cycles or dangling `nextId`
	/// - each task's `prevId` matches the task before it (nil for the head)
	/// - every task that belongs to `parent` is reachable, and nothing else is in the chain
	///
	/// Walks the chain itself instead of using the task stream, so a broken chain reports instead of hanging or throwing.
	func chainProblems(on parent: TaskParent) async throws -> [String] {
		let all = try await getAllTasks()
		let head: TaskItem.ID?
		let expected: Set<TaskItem.ID>
		let name: String

		switch parent {
		case .list(let id):
			guard let list = try await getList(id: id) else { return ["list \(id) is missing"] }
			head = list.firstTaskId
			expected = Set(all.filter { $0.listId == id && $0.subtaskParentId == nil }.map(\.id))
			name = "list '\(list.slug)'"
		case .task(let hashID):
			guard let task = try await getTask(hashID: hashID) else { return ["task \(hashID) is missing"] }
			head = task.firstSubtaskId
			expected = Set(all.filter { $0.subtaskParentId == task.id }.map(\.id))
			name = "subtasks of '\(task.label)'"
		}

		var problems: [String] = []
		var visited: [TaskItem.ID] = []
		var previousID: TaskItem.ID?
		var currentID = head
		while let id = currentID {
			guard visited.contains(id) == false else {
				problems.append("\(name): chain loops back to id \(id)")
				break
			}
			guard let task = try await getTask(id: id) else {
				problems.append("\(name): pointer to missing id \(id)")
				break
			}
			if task.prevId != previousID {
				problems.append("\(name): '\(task.label)' has prevId \(String(describing: task.prevId)), expected \(String(describing: previousID))")
			}
			visited.append(id)
			previousID = id
			currentID = task.nextId
		}

		let unreachable = expected.subtracting(visited)
		if unreachable.isEmpty == false {
			problems.append("\(name): unreachable ids \(unreachable.sorted())")
		}
		let foreign = Set(visited).subtracting(expected)
		if foreign.isEmpty == false {
			problems.append("\(name): chain includes ids that belong elsewhere \(foreign.sorted())")
		}
		return problems
	}

	/// `chainProblems` for the list itself and for every task's subtask chain.
	func integrityProblems(inList listID: TaskList.ID) async throws -> [String] {
		var problems = try await chainProblems(on: .list(listID))
		for task in try await getAllTasks() where task.listId == listID {
			problems += try await chainProblems(on: .task(hashID: task.itemHashId))
		}
		return problems
	}
}
