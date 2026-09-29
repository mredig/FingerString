import Testing
@testable import FingerStringLib

@Suite struct SubtaskTests {
	// MARK: - Create
	@Test func createStoresParentAndList() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.makeList()
		let parent = try await controller.addTask("parent", to: .list(list.id))

		let child = try await controller.addTask("child", to: .task(hashID: parent.itemHashId), note: "n")

		#expect(child.subtaskParentId == parent.id)
		#expect(child.listId == list.id)
		#expect(child.note == "n")
		#expect(child.isComplete == false)
		#expect(try await controller.getTask(id: parent.id)?.firstSubtaskId == child.id)
	}

	@Test func subtasksAppendInOrderAndLinkUp() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.makeList()
		let parent = try await controller.addTask("parent", to: .list(list.id))
		let parentRef = TaskParentRef(parent)

		let a = try await controller.addTask("a", to: parentRef.parent)
		let b = try await controller.addTask("b", to: parentRef.parent)
		let c = try await controller.addTask("c", to: parentRef.parent)

		#expect(try await controller.labels(on: parentRef.parent) == ["a", "b", "c"])
		#expect(try await controller.getTask(id: a.id)?.nextId == b.id)
		#expect(try await controller.getTask(id: b.id)?.prevId == a.id)
		#expect(try await controller.getTask(id: c.id)?.prevId == b.id)
		#expect(try await controller.getTask(id: c.id)?.nextId == nil)
		// only the first subtask is referenced by the parent
		#expect(try await controller.getTask(id: parent.id)?.firstSubtaskId == a.id)
	}

	@Test func subtasksDoNotAppearInParentList() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.makeList()
		let parent = try await controller.addTask("parent", to: .list(list.id))
		try await controller.addTask("child", to: .task(hashID: parent.itemHashId))
		try await controller.addTask("sibling", to: .list(list.id))

		#expect(try await controller.labels(on: .list(list.id)) == ["parent", "sibling"])
		#expect(try await controller.labels(on: .task(hashID: parent.itemHashId)) == ["child"])
		#expect(try await controller.getAllTasks().count == 3)
	}

	@Test func subtaskListsAreIndependentPerParent() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.makeList()
		let one = try await controller.addTask("one", to: .list(list.id))
		let two = try await controller.addTask("two", to: .list(list.id))

		try await controller.addTask("one-a", to: .task(hashID: one.itemHashId))
		try await controller.addTask("two-a", to: .task(hashID: two.itemHashId))
		try await controller.addTask("one-b", to: .task(hashID: one.itemHashId))

		#expect(try await controller.labels(on: .task(hashID: one.itemHashId)) == ["one-a", "one-b"])
		#expect(try await controller.labels(on: .task(hashID: two.itemHashId)) == ["two-a"])
	}

	@Test func nestedSubtasks() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.makeList()
		let top = try await controller.addTask("top", to: .list(list.id))
		let mid = try await controller.addTask("mid", to: .task(hashID: top.itemHashId))
		let leaf = try await controller.addTask("leaf", to: .task(hashID: mid.itemHashId))

		#expect(leaf.subtaskParentId == mid.id)
		#expect(try await controller.labels(on: .task(hashID: mid.itemHashId)) == ["leaf"])
	}

	@Test func createOnMissingParentThrows() async throws {
		let controller = try TestSupport.makeController()
		try await controller.makeList()

		await #expect(throws: (any Error).self) {
			try await controller.addTask("orphan", to: .task(hashID: "zzzzz"))
		}
	}

	// MARK: - Read
	@Test func getByIndexAndLast() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.makeList()
		let parent = try await controller.addTask("parent", to: .list(list.id))
		let parentRef = TaskParentRef(parent)
		try await controller.addTask("a", to: parentRef.parent)
		try await controller.addTask("b", to: parentRef.parent)

		#expect(try await controller.getTask(index: 1, on: parentRef.parent)?.label == "b")
		#expect(try await controller.getTask(index: 2, on: parentRef.parent) == nil)
		#expect(try await controller.getLastTask(on: parentRef.parent)?.label == "b")
	}

	@Test func parentWithoutSubtasksIsEmpty() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.makeList()
		let parent = try await controller.addTask("parent", to: .list(list.id))

		#expect(try await controller.getAllTasks(on: .task(hashID: parent.itemHashId)).isEmpty)
		#expect(try await controller.getLastTask(on: .task(hashID: parent.itemHashId)) == nil)
	}

	// MARK: - Update
	@Test func updateSubtask() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.makeList()
		let parent = try await controller.addTask("parent", to: .list(list.id))
		let child = try await controller.addTask("child", to: .task(hashID: parent.itemHashId))

		try await controller.updateTask(
			id: child.id,
			label: .change("renamed"),
			note: .change("noted"),
			isCompleted: .change(true))

		let fetched = try #require(try await controller.getTask(id: child.id))
		#expect(fetched.label == "renamed")
		#expect(fetched.note == "noted")
		#expect(fetched.isComplete == true)
		#expect(fetched.subtaskParentId == parent.id)
	}

	@Test func completingSubtaskDoesNotCompleteParent() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.makeList()
		let parent = try await controller.addTask("parent", to: .list(list.id))
		let child = try await controller.addTask("child", to: .task(hashID: parent.itemHashId))

		try await controller.updateTask(id: child.id, isCompleted: .change(true))

		#expect(try await controller.getTask(id: parent.id)?.isComplete == false)
	}

	// MARK: - Delete
	@Test func deleteOnlySubtaskClearsParentHead() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.makeList()
		let parent = try await controller.addTask("parent", to: .list(list.id))
		let child = try await controller.addTask("child", to: .task(hashID: parent.itemHashId))

		try await controller.deleteTask(child.id)

		#expect(try await controller.getTask(id: child.id) == nil)
		#expect(try await controller.getTask(id: parent.id)?.firstSubtaskId == nil)
		#expect(try await controller.getAllTasks(on: .task(hashID: parent.itemHashId)).isEmpty)
	}

	@Test func deleteFirstSubtaskPromotesNext() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.makeList()
		let parent = try await controller.addTask("parent", to: .list(list.id))
		let parentRef = TaskParentRef(parent)
		let a = try await controller.addTask("a", to: parentRef.parent)
		let b = try await controller.addTask("b", to: parentRef.parent)

		try await controller.deleteTask(a.id)

		#expect(try await controller.labels(on: parentRef.parent) == ["b"])
		#expect(try await controller.getTask(id: parent.id)?.firstSubtaskId == b.id)
		#expect(try await controller.getTask(id: b.id)?.prevId == nil)
	}

	@Test func deleteMiddleSubtaskRelinksNeighbors() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.makeList()
		let parent = try await controller.addTask("parent", to: .list(list.id))
		let parentRef = TaskParentRef(parent)
		let a = try await controller.addTask("a", to: parentRef.parent)
		let b = try await controller.addTask("b", to: parentRef.parent)
		let c = try await controller.addTask("c", to: parentRef.parent)

		try await controller.deleteTask(b.id)

		#expect(try await controller.labels(on: parentRef.parent) == ["a", "c"])
		#expect(try await controller.getTask(id: a.id)?.nextId == c.id)
		#expect(try await controller.getTask(id: c.id)?.prevId == a.id)
	}

	@Test func deleteLastSubtaskEndsChain() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.makeList()
		let parent = try await controller.addTask("parent", to: .list(list.id))
		let parentRef = TaskParentRef(parent)
		let a = try await controller.addTask("a", to: parentRef.parent)
		let b = try await controller.addTask("b", to: parentRef.parent)

		try await controller.deleteTask(b.id)

		#expect(try await controller.labels(on: parentRef.parent) == ["a"])
		#expect(try await controller.getTask(id: a.id)?.nextId == nil)
	}

	@Test func deleteSubtasksThenAddMore() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.makeList()
		let parent = try await controller.addTask("parent", to: .list(list.id))
		let parentRef = TaskParentRef(parent)
		let a = try await controller.addTask("a", to: parentRef.parent)
		let b = try await controller.addTask("b", to: parentRef.parent)
		try await controller.deleteTask(a.id)
		try await controller.deleteTask(b.id)

		try await controller.addTask("c", to: parentRef.parent)
		try await controller.addTask("d", to: parentRef.parent)

		#expect(try await controller.labels(on: parentRef.parent) == ["c", "d"])
	}

	@Test func deleteSubtaskLeavesParentListIntact() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.makeList()
		let parent = try await controller.addTask("parent", to: .list(list.id))
		try await controller.addTask("sibling", to: .list(list.id))
		let child = try await controller.addTask("child", to: .task(hashID: parent.itemHashId))

		try await controller.deleteTask(child.id)

		#expect(try await controller.labels(on: .list(list.id)) == ["parent", "sibling"])
	}

	@Test func deleteParentCascadesToSubtasks() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.makeList()
		let parent = try await controller.addTask("parent", to: .list(list.id))
		let child = try await controller.addTask("child", to: .task(hashID: parent.itemHashId))
		try await controller.addTask("grandchild", to: .task(hashID: child.itemHashId))
		try await controller.addTask("bystander", to: .list(list.id))

		try await controller.deleteTask(parent.id)

		#expect(try await controller.getAllTasks().map(\.label) == ["bystander"])
		#expect(try await controller.labels(on: .list(list.id)) == ["bystander"])
	}
}

/// Small convenience so tests don't repeat `.task(hashID: parent.itemHashId)`.
private struct TaskParentRef {
	let parent: ListController.TaskParent

	init(_ task: TaskItem) {
		parent = .task(hashID: task.itemHashId)
	}
}
