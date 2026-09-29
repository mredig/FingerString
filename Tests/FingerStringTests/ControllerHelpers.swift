import FingerStringLib
import Testing

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
	func chainProblems(on parent: TaskParent, sourceLocation: SourceLocation) async throws {
		let all = try await getAllTasks()
		let head: TaskItem.ID?
		let expected: Set<TaskItem.ID>
		let name: String

		switch parent {
		case .list(let id):
			guard let list = try await getList(id: id) else {
				Issue.record("list \(id) is missing", severity: .error, sourceLocation: sourceLocation)
				return
			}
			head = list.firstTaskId
			expected = Set(all.filter { $0.listId == id && $0.subtaskParentId == nil }.map(\.id))
			name = "list '\(list.slug)'"
		case .task(let hashID):
			guard let task = try await getTask(hashID: hashID) else {
				Issue.record("task \(hashID) is missing", severity: .error, sourceLocation: sourceLocation)
				return
			}
			head = task.firstSubtaskId
			expected = Set(all.filter { $0.subtaskParentId == task.id }.map(\.id))
			name = "subtasks of '\(task.label)'"
		}

		var visited: [TaskItem.ID] = []
		var previousID: TaskItem.ID?
		var currentID = head
		while let id = currentID {
			guard visited.contains(id) == false else {
				Issue.record("\(name): chain loops back to id \(id)", severity: .error, sourceLocation: sourceLocation)
				break
			}
			guard let task = try await getTask(id: id) else {
				Issue.record("\(name): pointer to missing id \(id)", severity: .error, sourceLocation: sourceLocation)
				break
			}
			if task.prevId != previousID {
				Issue.record("\(name): '\(task.label)' has prevId \(task.prevId), expected \(previousID)", severity: .error, sourceLocation: sourceLocation)
			}
			visited.append(id)
			previousID = id
			currentID = task.nextId
		}

		let unreachable = expected.subtracting(visited)
		if unreachable.isEmpty == false {
			Issue.record("\(name): unreachable ids \(unreachable.sorted())", severity: .error, sourceLocation: sourceLocation)
		}
		let foreign = Set(visited).subtracting(expected)
		if foreign.isEmpty == false {
			Issue.record("\(name): chain includes ids that belong elsewhere \(foreign.sorted())", severity: .error, sourceLocation: sourceLocation)
		}
	}

	/// `chainProblems` for the list itself and for every task's subtask chain.
	func integrityProblems(inList listID: TaskList.ID, fileID: String = #fileID, filePath: String = #filePath, line: Int = #line, column: Int = #column) async throws {
		let sourceLocation = SourceLocation(fileID: fileID, filePath: filePath, line: line, column: column)
		try await chainProblems(on: .list(listID), sourceLocation: sourceLocation)
		for task in try await getAllTasks() where task.listId == listID {
			try await chainProblems(on: .task(hashID: task.itemHashId), sourceLocation: sourceLocation)
		}
	}
}
