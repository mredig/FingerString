import Testing
import FingerStringLib

/// Every move test checks the destination *and* the source: `integrityProblems` verifies each list's
/// head pointer, `prevId`/`nextId` links, and that every task is reachable from exactly one chain.
@Suite struct MoveTaskTests {
	private func makeTwoLists() async throws -> (controller: ListController, a: TaskList, b: TaskList) {
		let controller = try TestSupport.makeController()
		let a = try await controller.makeList("list-a")
		let b = try await controller.makeList("list-b")
		return (controller, a, b)
	}

	private func expectIntact(
		_ controller: ListController,
		_ lists: TaskList...,
		fileID: String = #fileID,
		filePath: String = #filePath,
		line: Int = #line,
		column: Int = #column
	) async throws {
		for list in lists {
			try await controller.integrityProblems(inList: list.id, fileID: fileID, filePath: filePath, line: line, column: column)
		}
	}

	// MARK: - List -> List
	@Test func moveMiddleTaskToAnotherList() async throws {
		let (controller, a, b) = try await makeTwoLists()
		let a1 = try await controller.addTask("a1", to: .list(a.id))
		let a2 = try await controller.addTask("a2", to: .list(a.id))
		let a3 = try await controller.addTask("a3", to: .list(a.id))
		let b1 = try await controller.addTask("b1", to: .list(b.id))

		try await controller.moveTask(a2.id, to: .list(b.id))

		#expect(try await controller.labels(on: .list(a.id)) == ["a1", "a3"])
		#expect(try await controller.labels(on: .list(b.id)) == ["b1", "a2"])
		let moved = try #require(try await controller.getTask(id: a2.id))
		#expect(moved.listId == b.id)
		#expect(moved.subtaskParentId == nil)
		#expect(moved.prevId == b1.id)
		#expect(moved.nextId == nil)
		#expect(try await controller.getTask(id: a1.id)?.nextId == a3.id)
		#expect(try await controller.getTask(id: a3.id)?.prevId == a1.id)
		try await expectIntact(controller, a, b)
	}

	@Test func moveFirstTaskToAnotherList() async throws {
		let (controller, a, b) = try await makeTwoLists()
		let a1 = try await controller.addTask("a1", to: .list(a.id))
		let a2 = try await controller.addTask("a2", to: .list(a.id))
		try await controller.addTask("b1", to: .list(b.id))

		try await controller.moveTask(a1.id, to: .list(b.id))

		#expect(try await controller.getList(id: a.id)?.firstTaskId == a2.id)
		#expect(try await controller.getTask(id: a2.id)?.prevId == nil)
		#expect(try await controller.labels(on: .list(a.id)) == ["a2"])
		#expect(try await controller.labels(on: .list(b.id)) == ["b1", "a1"])
		try await expectIntact(controller, a, b)
	}

	@Test func moveLastTaskToAnotherList() async throws {
		let (controller, a, b) = try await makeTwoLists()
		let a1 = try await controller.addTask("a1", to: .list(a.id))
		let a2 = try await controller.addTask("a2", to: .list(a.id))
		try await controller.addTask("b1", to: .list(b.id))

		try await controller.moveTask(a2.id, to: .list(b.id))

		#expect(try await controller.getTask(id: a1.id)?.nextId == nil)
		#expect(try await controller.labels(on: .list(a.id)) == ["a1"])
		try await expectIntact(controller, a, b)
	}

	@Test func moveOnlyTaskToEmptyList() async throws {
		let (controller, a, b) = try await makeTwoLists()
		let only = try await controller.addTask("only", to: .list(a.id))

		try await controller.moveTask(only.id, to: .list(b.id))

		#expect(try await controller.getList(id: a.id)?.firstTaskId == nil)
		#expect(try await controller.getList(id: b.id)?.firstTaskId == only.id)
		#expect(try await controller.labels(on: .list(a.id)) == [])
		#expect(try await controller.labels(on: .list(b.id)) == ["only"])
		try await expectIntact(controller, a, b)
	}

	// MARK: - List -> Subtask
	@Test func moveListTaskToSubtaskParentWithExistingSubtasks() async throws {
		let (controller, a, _) = try await makeTwoLists()
		let t1 = try await controller.addTask("t1", to: .list(a.id))
		let t2 = try await controller.addTask("t2", to: .list(a.id))
		let parent = try await controller.addTask("parent", to: .list(a.id))
		let existing = try await controller.addTask("existing", to: .task(hashID: parent.itemHashId))

		try await controller.moveTask(t1.id, to: .task(hashID: parent.itemHashId))

		#expect(try await controller.labels(on: .list(a.id)) == ["t2", "parent"])
		#expect(try await controller.labels(on: .task(hashID: parent.itemHashId)) == ["existing", "t1"])
		let moved = try #require(try await controller.getTask(id: t1.id))
		#expect(moved.subtaskParentId == parent.id)
		#expect(moved.listId == a.id)
		#expect(moved.prevId == existing.id)
		#expect(moved.nextId == nil)
		#expect(try await controller.getList(id: a.id)?.firstTaskId == t2.id)
		try await expectIntact(controller, a)
	}

	@Test func moveListTaskToSubtaskParentWithNoSubtasks() async throws {
		let (controller, a, _) = try await makeTwoLists()
		let task = try await controller.addTask("task", to: .list(a.id))
		let parent = try await controller.addTask("parent", to: .list(a.id))

		try await controller.moveTask(task.id, to: .task(hashID: parent.itemHashId))

		#expect(try await controller.getTask(id: parent.id)?.firstSubtaskId == task.id)
		#expect(try await controller.labels(on: .task(hashID: parent.itemHashId)) == ["task"])
		#expect(try await controller.labels(on: .list(a.id)) == ["parent"])
		try await expectIntact(controller, a)
	}

	@Test func moveListTaskToSubtaskParentOnAnotherList() async throws {
		let (controller, a, b) = try await makeTwoLists()
		let task = try await controller.addTask("task", to: .list(a.id))
		let parent = try await controller.addTask("parent", to: .list(b.id))

		try await controller.moveTask(task.id, to: .task(hashID: parent.itemHashId))

		let moved = try #require(try await controller.getTask(id: task.id))
		#expect(moved.listId == b.id)
		#expect(moved.subtaskParentId == parent.id)
		#expect(try await controller.labels(on: .list(a.id)) == [])
		#expect(try await controller.getList(id: a.id)?.firstTaskId == nil)
		try await expectIntact(controller, a, b)
	}

	// MARK: - Subtask -> List
	@Test func moveMiddleSubtaskToItsOwnList() async throws {
		let (controller, a, _) = try await makeTwoLists()
		let parent = try await controller.addTask("parent", to: .list(a.id))
		try await controller.addTask("other", to: .list(a.id))
		let parentRef = ListController.TaskParent.task(hashID: parent.itemHashId)
		let s1 = try await controller.addTask("s1", to: parentRef)
		let s2 = try await controller.addTask("s2", to: parentRef)
		let s3 = try await controller.addTask("s3", to: parentRef)

		try await controller.moveTask(s2.id, to: .list(a.id))

		#expect(try await controller.labels(on: .list(a.id)) == ["parent", "other", "s2"])
		#expect(try await controller.labels(on: parentRef) == ["s1", "s3"])
		let moved = try #require(try await controller.getTask(id: s2.id))
		#expect(moved.subtaskParentId == nil)
		#expect(moved.listId == a.id)
		#expect(try await controller.getTask(id: s1.id)?.nextId == s3.id)
		#expect(try await controller.getTask(id: s3.id)?.prevId == s1.id)
		try await expectIntact(controller, a)
	}

	@Test func moveFirstSubtaskToList() async throws {
		let (controller, a, _) = try await makeTwoLists()
		let parent = try await controller.addTask("parent", to: .list(a.id))
		let parentRef = ListController.TaskParent.task(hashID: parent.itemHashId)
		let s1 = try await controller.addTask("s1", to: parentRef)
		let s2 = try await controller.addTask("s2", to: parentRef)

		try await controller.moveTask(s1.id, to: .list(a.id))

		#expect(try await controller.getTask(id: parent.id)?.firstSubtaskId == s2.id)
		#expect(try await controller.getTask(id: s2.id)?.prevId == nil)
		try await expectIntact(controller, a)
	}

	@Test func moveOnlySubtaskToList() async throws {
		let (controller, a, _) = try await makeTwoLists()
		let parent = try await controller.addTask("parent", to: .list(a.id))
		let only = try await controller.addTask("only", to: .task(hashID: parent.itemHashId))

		try await controller.moveTask(only.id, to: .list(a.id))

		#expect(try await controller.getTask(id: parent.id)?.firstSubtaskId == nil)
		#expect(try await controller.labels(on: .list(a.id)) == ["parent", "only"])
		try await expectIntact(controller, a)
	}

	@Test func moveSubtaskToAnotherList() async throws {
		let (controller, a, b) = try await makeTwoLists()
		let parent = try await controller.addTask("parent", to: .list(a.id))
		let sub = try await controller.addTask("sub", to: .task(hashID: parent.itemHashId))
		try await controller.addTask("b1", to: .list(b.id))

		try await controller.moveTask(sub.id, to: .list(b.id))

		let moved = try #require(try await controller.getTask(id: sub.id))
		#expect(moved.listId == b.id)
		#expect(moved.subtaskParentId == nil)
		#expect(try await controller.labels(on: .list(b.id)) == ["b1", "sub"])
		#expect(try await controller.getTask(id: parent.id)?.firstSubtaskId == nil)
		try await expectIntact(controller, a, b)
	}

	@Test func moveSubtaskToEmptyList() async throws {
		let (controller, a, b) = try await makeTwoLists()
		let parent = try await controller.addTask("parent", to: .list(a.id))
		let sub = try await controller.addTask("sub", to: .task(hashID: parent.itemHashId))

		try await controller.moveTask(sub.id, to: .list(b.id))

		#expect(try await controller.getList(id: b.id)?.firstTaskId == sub.id)
		try await expectIntact(controller, a, b)
	}

	// MARK: - Tasks with subtasks
	@Test func moveTaskWithSubtasksToAnotherList() async throws {
		let (controller, a, b) = try await makeTwoLists()
		let mover = try await controller.addTask("mover", to: .list(a.id))
		let moverRef = ListController.TaskParent.task(hashID: mover.itemHashId)
		let c1 = try await controller.addTask("c1", to: moverRef)
		let c2 = try await controller.addTask("c2", to: moverRef)
		try await controller.addTask("b1", to: .list(b.id))

		try await controller.moveTask(mover.id, to: .list(b.id))

		#expect(try await controller.labels(on: .list(b.id)) == ["b1", "mover"])
		#expect(try await controller.labels(on: moverRef) == ["c1", "c2"])
		#expect(try await controller.getTask(id: c1.id)?.listId == b.id)
		#expect(try await controller.getTask(id: c2.id)?.listId == b.id)
		#expect(try await controller.getTask(id: c1.id)?.subtaskParentId == mover.id)
		#expect(try await controller.getAllTasks(on: .list(a.id)).isEmpty)
		try await expectIntact(controller, a, b)
	}

	@Test func moveTaskWithSubtasksIntoASubtaskOnAnotherList() async throws {
		let (controller, a, b) = try await makeTwoLists()
		let mover = try await controller.addTask("mover", to: .list(a.id))
		let child = try await controller.addTask("child", to: .task(hashID: mover.itemHashId))
		let target = try await controller.addTask("target", to: .list(b.id))

		try await controller.moveTask(mover.id, to: .task(hashID: target.itemHashId))

		#expect(try await controller.getTask(id: mover.id)?.listId == b.id)
		#expect(try await controller.getTask(id: mover.id)?.subtaskParentId == target.id)
		#expect(try await controller.getTask(id: child.id)?.listId == b.id)
		#expect(try await controller.labels(on: .task(hashID: target.itemHashId)) == ["mover"])
		try await expectIntact(controller, a, b)
	}

	// MARK: - Tasks with subtasks that have subtasks
	private func makeDeepTree(on controller: ListController, list: TaskList) async throws -> (root: TaskItem, all: [TaskItem]) {
		let root = try await controller.addTask("root", to: .list(list.id))
		let rootRef = ListController.TaskParent.task(hashID: root.itemHashId)
		let c1 = try await controller.addTask("c1", to: rootRef)
		let c2 = try await controller.addTask("c2", to: rootRef)
		let c1Ref = ListController.TaskParent.task(hashID: c1.itemHashId)
		let g1 = try await controller.addTask("g1", to: c1Ref)
		let g2 = try await controller.addTask("g2", to: c1Ref)
		let g3 = try await controller.addTask("g3", to: .task(hashID: c2.itemHashId))
		let deep = try await controller.addTask("deep", to: .task(hashID: g3.itemHashId))
		return (root, [root, c1, c2, g1, g2, g3, deep])
	}

	private let deepOutline = [
		"root",
		"\tc1",
		"\t\tg1",
		"\t\tg2",
		"\tc2",
		"\t\tg3",
		"\t\t\tdeep",
	]

	@Test func moveDeepTreeToAnotherList() async throws {
		let (controller, a, b) = try await makeTwoLists()
		let (root, all) = try await makeDeepTree(on: controller, list: a)
		try await controller.addTask("b1", to: .list(b.id))
		try await controller.addTask("a-other", to: .list(a.id))

		try await controller.moveTask(root.id, to: .list(b.id))

		for task in all {
			#expect(try await controller.getTask(id: task.id)?.listId == b.id, "\(task.label) should be on list b")
		}
		#expect(try await controller.outline(on: .list(b.id)) == ["b1"] + deepOutline)
		#expect(try await controller.outline(on: .list(a.id)) == ["a-other"])
		try await expectIntact(controller, a, b)
	}

	@Test func moveDeepTreeIntoASubtaskOnAnotherList() async throws {
		let (controller, a, b) = try await makeTwoLists()
		let (root, all) = try await makeDeepTree(on: controller, list: a)
		let target = try await controller.addTask("target", to: .list(b.id))

		try await controller.moveTask(root.id, to: .task(hashID: target.itemHashId))

		for task in all {
			#expect(try await controller.getTask(id: task.id)?.listId == b.id, "\(task.label) should be on list b")
		}
		#expect(try await controller.outline(on: .list(b.id)) == ["target"] + deepOutline.map { "\t" + $0 })
		#expect(try await controller.getAllTasks(on: .list(a.id)).isEmpty)
		try await expectIntact(controller, a, b)
	}

	@Test func moveDeepTreeSubbranchToList() async throws {
		let (controller, a, b) = try await makeTwoLists()
		let (root, all) = try await makeDeepTree(on: controller, list: a)
		let c2 = try #require(all.first { $0.label == "c2" })

		try await controller.moveTask(c2.id, to: .list(b.id))

		#expect(try await controller.outline(on: .list(a.id)) == ["root", "\tc1", "\t\tg1", "\t\tg2"])
		#expect(try await controller.outline(on: .list(b.id)) == ["c2", "\tg3", "\t\tdeep"])
		for label in ["c2", "g3", "deep"] {
			let task = try #require(all.first { $0.label == label })
			#expect(try await controller.getTask(id: task.id)?.listId == b.id, "\(label) should be on list b")
		}
		#expect(try await controller.getTask(id: root.id)?.listId == a.id)
		try await expectIntact(controller, a, b)
	}

	// MARK: - Guards
	@Test func cannotMoveTaskToItself() async throws {
		let (controller, a, _) = try await makeTwoLists()
		let task = try await controller.addTask("task", to: .list(a.id))

		await #expect(throws: ListController.MoveError.cannotMoveTaskToItself) {
			try await controller.moveTask(task.id, to: .task(hashID: task.itemHashId))
		}
		try await expectIntact(controller, a)
	}

	@Test func cannotMoveTaskToItselfUsingUppercaseHash() async throws {
		let (controller, a, _) = try await makeTwoLists()
		let task = try await controller.addTask("task", to: .list(a.id))

		await #expect(throws: ListController.MoveError.cannotMoveTaskToItself) {
			try await controller.moveTask(task.id, to: .task(hashID: task.itemHashId.uppercased()))
		}
		#expect(try await controller.getTask(id: task.id)?.subtaskParentId == nil)
		try await expectIntact(controller, a)
	}

	@Test func cannotMoveTaskToItsChild() async throws {
		let (controller, a, _) = try await makeTwoLists()
		let parent = try await controller.addTask("parent", to: .list(a.id))
		let child = try await controller.addTask("child", to: .task(hashID: parent.itemHashId))

		await #expect(throws: ListController.MoveError.cannotMoveTaskToChildTask) {
			try await controller.moveTask(parent.id, to: .task(hashID: child.itemHashId))
		}
		try await expectIntact(controller, a)
	}

	@Test func cannotMoveTaskToItsGrandchild() async throws {
		let (controller, a, _) = try await makeTwoLists()
		let (root, all) = try await makeDeepTree(on: controller, list: a)
		let deep = try #require(all.first { $0.label == "deep" })

		await #expect(throws: ListController.MoveError.cannotMoveTaskToChildTask) {
			try await controller.moveTask(root.id, to: .task(hashID: deep.itemHashId))
		}
		#expect(try await controller.outline(on: .list(a.id)) == deepOutline)
		try await expectIntact(controller, a)
	}

	@Test func movingToMissingListThrowsAndChangesNothing() async throws {
		let (controller, a, _) = try await makeTwoLists()
		let task = try await controller.addTask("task", to: .list(a.id))

		await #expect(throws: ListController.ReadError.noMatchingList) {
			try await controller.moveTask(task.id, to: .list(999))
		}
		#expect(try await controller.labels(on: .list(a.id)) == ["task"])
		try await expectIntact(controller, a)
	}

	@Test func movingToMissingTaskThrowsAndChangesNothing() async throws {
		let (controller, a, _) = try await makeTwoLists()
		let task = try await controller.addTask("task", to: .list(a.id))

		await #expect(throws: ListController.ReadError.doesntExist) {
			try await controller.moveTask(task.id, to: .task(hashID: "zzzzz"))
		}
		#expect(try await controller.labels(on: .list(a.id)) == ["task"])
		try await expectIntact(controller, a)
	}

	@Test func movingMissingTaskThrows() async throws {
		let (controller, a, _) = try await makeTwoLists()

		await #expect(throws: ListController.ReadError.doesntExist) {
			try await controller.moveTask(999, to: .list(a.id))
		}
	}

	// MARK: - Moves that shouldn't change the tree
	@Test func movingTopLevelTaskToItsOwnListChangesNothing() async throws {
		let (controller, a, _) = try await makeTwoLists()
		try await controller.addTask("first", to: .list(a.id))
		let second = try await controller.addTask("second", to: .list(a.id))
		try await controller.addTask("third", to: .list(a.id))

		try await controller.moveTask(second.id, to: .list(a.id))

		#expect(try await controller.labels(on: .list(a.id)) == ["first", "second", "third"])
		try await expectIntact(controller, a)
	}

	@Test func movingLastSubtaskToItsCurrentParentKeepsTreeIntact() async throws {
		let (controller, a, _) = try await makeTwoLists()
		let parent = try await controller.addTask("parent", to: .list(a.id))
		let parentRef = ListController.TaskParent.task(hashID: parent.itemHashId)
		try await controller.addTask("s1", to: parentRef)
		let s2 = try await controller.addTask("s2", to: parentRef)

		try await controller.moveTask(s2.id, to: parentRef)

		// check the chain by hand first: a task linked to itself would make the task stream loop forever
		try await controller.integrityProblems(inList: a.id)
		#expect(try await controller.labels(on: parentRef).sorted() == ["s1", "s2"])
	}

	@Test func movingFirstSubtaskToItsCurrentParentKeepsTreeIntact() async throws {
		let (controller, a, _) = try await makeTwoLists()
		let parent = try await controller.addTask("parent", to: .list(a.id))
		let parentRef = ListController.TaskParent.task(hashID: parent.itemHashId)
		let s1 = try await controller.addTask("s1", to: parentRef)
		try await controller.addTask("s2", to: parentRef)

		try await controller.moveTask(s1.id, to: parentRef)

		try await controller.integrityProblems(inList: a.id)
		#expect(try await controller.labels(on: parentRef).sorted() == ["s1", "s2"])
	}
}
