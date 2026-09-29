import Testing
import FingerStringLib

@Suite struct ListTests {
	@Test func createStoresFields() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.createList(with: "Groceries", friendlyTitle: "Food Run", description: "weekly")

		#expect(list.slug == "groceries")
		#expect(list.title == "Food Run")
		#expect(list.description == "weekly")
		#expect(list.firstTaskId == nil)
	}

	@Test func createWithoutOptionalFields() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.makeList("bare")

		#expect(list.title == nil)
		#expect(list.description == nil)
	}

	@Test func duplicateSlugThrows() async throws {
		let controller = try TestSupport.makeController()
		try await controller.makeList("dupe")

		await #expect(throws: (any Error).self) {
			try await controller.makeList("DUPE")
		}
		#expect(try await controller.getAllLists().count == 1)
	}

	@Test func getByIDAndSlug() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.makeList("find-me")

		#expect(try await controller.getList(id: list.id)?.id == list.id)
		#expect(try await controller.getList(withSlug: "find-me")?.id == list.id)
	}

	@Test func getMissingReturnsNil() async throws {
		let controller = try TestSupport.makeController()

		#expect(try await controller.getList(id: 999) == nil)
		#expect(try await controller.getList(withSlug: "nope") == nil)
	}

	@Test func getAllListsReturnsEveryList() async throws {
		let controller = try TestSupport.makeController()
		#expect(try await controller.getAllLists().isEmpty)

		try await controller.makeList("one")
		try await controller.makeList("two")

		let slugs = try await controller.getAllLists().map(\.slug).sorted()
		#expect(slugs == ["one", "two"])
	}

	@Test func deleteRemovesList() async throws {
		let controller = try TestSupport.makeController()
		let list = try await controller.makeList()

		try await controller.deleteList(list.id)

		#expect(try await controller.getList(id: list.id) == nil)
		#expect(try await controller.getAllLists().isEmpty)
	}

	@Test func deleteMissingListIsNoOp() async throws {
		let controller = try TestSupport.makeController()
		try await controller.makeList("keep")

		try await controller.deleteList(999)

		#expect(try await controller.getAllLists().count == 1)
	}

	@Test func deleteListCascadesToTasksAndSubtasks() async throws {
		let controller = try TestSupport.makeController()
		let doomed = try await controller.makeList("doomed")
		let kept = try await controller.makeList("kept")
		let parent = try await controller.addTask("parent", to: .list(doomed.id))
		try await controller.addTask("child", to: .task(hashID: parent.itemHashId))
		try await controller.addTask("survivor", to: .list(kept.id))

		try await controller.deleteList(doomed.id)

		#expect(try await controller.getAllTasks().map(\.label) == ["survivor"])
	}

	@Test func storesAreIsolated() async throws {
		let a = try TestSupport.makeController()
		let b = try TestSupport.makeController()
		try await a.makeList("only-a")

		#expect(try await a.getAllLists().count == 1)
		#expect(try await b.getAllLists().isEmpty)
	}
}
