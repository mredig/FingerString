import Testing
@testable import FingerStringLib

@Suite struct TaskTests {
	// MARK: - Create
	@Test func createStoresFields() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.makeList()

		let task = try await controller.addTask("write tests", to: .list(list.id), note: "soon")

		#expect(task.label == "write tests")
		#expect(task.note == "soon")
		#expect(task.isComplete == false)
		#expect(task.listId == list.id)
		#expect(task.subtaskParentId == nil)
		#expect(task.prevId == nil)
		#expect(task.nextId == nil)
		#expect(task.itemHashId.count == Constants.hashIDLength)
	}

	@Test func firstTaskBecomesListHead() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.makeList()

		let first = try await controller.addTask("first", to: .list(list.id))
		try await controller.addTask("second", to: .list(list.id))

		#expect(try await controller.getList(id: list.id)?.firstTaskId == first.id)
	}

	@Test func tasksAppendInOrderAndLinkUp() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.makeList()

		let a = try await controller.addTask("a", to: .list(list.id))
		let b = try await controller.addTask("b", to: .list(list.id))
		let c = try await controller.addTask("c", to: .list(list.id))

		#expect(try await controller.labels(on: .list(list.id)) == ["a", "b", "c"])
		#expect(try await controller.getTask(id: a.id)?.nextId == b.id)
		#expect(try await controller.getTask(id: b.id)?.prevId == a.id)
		#expect(try await controller.getTask(id: b.id)?.nextId == c.id)
		#expect(try await controller.getTask(id: c.id)?.prevId == b.id)
		#expect(try await controller.getTask(id: c.id)?.nextId == nil)
	}

	@Test func identicalLabelsGetDistinctHashIDs() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.makeList()

		let one = try await controller.addTask("same", to: .list(list.id))
		let two = try await controller.addTask("same", to: .list(list.id))

		#expect(one.itemHashId != two.itemHashId)
		#expect(try await controller.getAllTasks(on: .list(list.id)).count == 2)
	}

	@Test func createOnMissingListThrows() async throws {
		let controller = try TestSupport.makeController()

		await #expect(throws: (any Error).self) {
			try await controller.addTask("orphan", to: .list(999))
		}
		#expect(try await controller.getAllTasks().isEmpty)
	}

	@Test func tasksStayOnTheirOwnList() async throws {
		let controller = try TestSupport.makeController()
		let one = try await controller.makeList("one")
		let two = try await controller.makeList("two")

		try await controller.addTask("a", to: .list(one.id))
		try await controller.addTask("b", to: .list(two.id))

		#expect(try await controller.labels(on: .list(one.id)) == ["a"])
		#expect(try await controller.labels(on: .list(two.id)) == ["b"])
	}

	// MARK: - Read
	@Test func getByIDAndHashID() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.makeList()
		let task = try await controller.addTask("find me", to: .list(list.id))

		#expect(try await controller.getTask(id: task.id)?.label == "find me")
		#expect(try await controller.getTask(hashID: task.itemHashId)?.id == task.id)
	}

	@Test func getByHashIDIsCaseInsensitive() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.makeList()
		let task = try await controller.addTask("find me", to: .list(list.id))

		#expect(try await controller.getTask(hashID: task.itemHashId.uppercased())?.id == task.id)
	}

	@Test func getMissingReturnsNil() async throws {
		let controller = try TestSupport.makeController()

		#expect(try await controller.getTask(id: 999) == nil)
		#expect(try await controller.getTask(hashID: "zzzzz") == nil)
	}

	@Test func getByIndex() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.makeList()
		try await controller.addTask("a", to: .list(list.id))
		try await controller.addTask("b", to: .list(list.id))
		try await controller.addTask("c", to: .list(list.id))

		#expect(try await controller.getTask(index: 0, on: .list(list.id))?.label == "a")
		#expect(try await controller.getTask(index: 2, on: .list(list.id))?.label == "c")
		#expect(try await controller.getTask(index: 3, on: .list(list.id)) == nil)
		#expect(try await controller.getTask(index: -1, on: .list(list.id)) == nil)
	}

	@Test func getLastTask() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.makeList()
		#expect(try await controller.getLastTask(on: .list(list.id)) == nil)

		try await controller.addTask("a", to: .list(list.id))
		try await controller.addTask("b", to: .list(list.id))

		#expect(try await controller.getLastTask(on: .list(list.id))?.label == "b")
	}

	@Test func getAllTasksOnEmptyListIsEmpty() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.makeList()

		#expect(try await controller.getAllTasks(on: .list(list.id)).isEmpty)
	}

	// MARK: - Update
	@Test func updateLabel() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.makeList()
		let task = try await controller.addTask("old", to: .list(list.id), note: "keep")

		let updated = try await controller.updateTask(id: task.id, label: .change("new"))

		#expect(updated.label == "new")
		#expect(updated.note == "keep")
		#expect(try await controller.getTask(id: task.id)?.label == "new")
	}

	@Test func updateNoteSetAndClear() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.makeList()
		let task = try await controller.addTask("t", to: .list(list.id))

		try await controller.updateTask(id: task.id, note: .change("hello"))
		#expect(try await controller.getTask(id: task.id)?.note == "hello")

		try await controller.updateTask(id: task.id, note: .change(nil))
		#expect(try await controller.getTask(id: task.id)?.note == nil)
	}

	@Test func updateCompletionToggles() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.makeList()
		let task = try await controller.addTask("t", to: .list(list.id))

		try await controller.updateTask(id: task.id, isCompleted: .change(true))
		#expect(try await controller.getTask(id: task.id)?.isComplete == true)

		try await controller.updateTask(id: task.id, isCompleted: .change(false))
		#expect(try await controller.getTask(id: task.id)?.isComplete == false)
	}

	@Test func updateWithNoChangesLeavesTaskAlone() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.makeList()
		let task = try await controller.addTask("t", to: .list(list.id), note: "n")

		let updated = try await controller.updateTask(id: task.id)

		#expect(updated.label == "t")
		#expect(updated.note == "n")
		#expect(updated.isComplete == false)
	}

	@Test func updateDoesNotDisturbOrdering() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.makeList()
		try await controller.addTask("a", to: .list(list.id))
		let b = try await controller.addTask("b", to: .list(list.id))
		try await controller.addTask("c", to: .list(list.id))

		try await controller.updateTask(id: b.id, label: .change("B"), isCompleted: .change(true))

		#expect(try await controller.labels(on: .list(list.id)) == ["a", "B", "c"])
	}

	@Test func updateMissingTaskThrows() async throws {
		let controller = try TestSupport.makeController()

		await #expect(throws: (any Error).self) {
			try await controller.updateTask(id: 999, label: .change("x"))
		}
	}

	// MARK: - Delete
	@Test func deleteOnlyTaskEmptiesList() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.makeList()
		let task = try await controller.addTask("solo", to: .list(list.id))

		try await controller.deleteTask(task.id)

		#expect(try await controller.getTask(id: task.id) == nil)
		#expect(try await controller.getList(id: list.id)?.firstTaskId == nil)
		#expect(try await controller.getAllTasks(on: .list(list.id)).isEmpty)
	}

	@Test func deleteFirstTaskPromotesNext() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.makeList()
		let a = try await controller.addTask("a", to: .list(list.id))
		let b = try await controller.addTask("b", to: .list(list.id))
		try await controller.addTask("c", to: .list(list.id))

		try await controller.deleteTask(a.id)

		#expect(try await controller.labels(on: .list(list.id)) == ["b", "c"])
		#expect(try await controller.getList(id: list.id)?.firstTaskId == b.id)
		#expect(try await controller.getTask(id: b.id)?.prevId == nil)
	}

	@Test func deleteMiddleTaskRelinksNeighbors() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.makeList()
		let a = try await controller.addTask("a", to: .list(list.id))
		let b = try await controller.addTask("b", to: .list(list.id))
		let c = try await controller.addTask("c", to: .list(list.id))

		try await controller.deleteTask(b.id)

		#expect(try await controller.labels(on: .list(list.id)) == ["a", "c"])
		#expect(try await controller.getTask(id: a.id)?.nextId == c.id)
		#expect(try await controller.getTask(id: c.id)?.prevId == a.id)
	}

	@Test func deleteLastTaskEndsList() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.makeList()
		let a = try await controller.addTask("a", to: .list(list.id))
		let b = try await controller.addTask("b", to: .list(list.id))

		try await controller.deleteTask(b.id)

		#expect(try await controller.labels(on: .list(list.id)) == ["a"])
		#expect(try await controller.getTask(id: a.id)?.nextId == nil)
	}

	@Test func appendAfterDeletingLastTask() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.makeList()
		try await controller.addTask("a", to: .list(list.id))
		let b = try await controller.addTask("b", to: .list(list.id))
		try await controller.deleteTask(b.id)

		try await controller.addTask("c", to: .list(list.id))

		#expect(try await controller.labels(on: .list(list.id)) == ["a", "c"])
	}

	@Test func deleteMissingTaskIsNoOp() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.makeList()
		try await controller.addTask("a", to: .list(list.id))

		try await controller.deleteTask(999)

		#expect(try await controller.labels(on: .list(list.id)) == ["a"])
	}
}
