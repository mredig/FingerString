import ArgumentParser
import FingerStringLib
import Foundation

struct ListView: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "list-view",
		abstract: "View a list and its items"
	)

	@Argument(help: "Slug of the list to view", completion: .custom({ _, _, prefix in
		do {
			let lists = try await FingerStringCLI.controller.getAllLists()
			guard lists.isOccupied else {
				print("No lists with prefix \(prefix)")
				return []
			}

			return lists.filter { $0.slug.hasPrefix(prefix) }.map(\.slug)
		} catch {
			print("Error: \(error)")
			return []
		}
	}))
	var slug: String

	@Flag
	var showCompletedTasks: Bool = false

	@Flag
	var showNotes: Bool = false

	func run() async throws {
		guard
			let list = try await FingerStringCLI.controller.getList(withSlug: slug)
		else {
			print("No list with the slug '\(slug)'")
			return
		}

		let listOutputBuilder = [
			list.headerTitle,
			list.description
		]

		print(listOutputBuilder.compactMap(\.self).joined(separator: "\n"))
		print()

		let itemsStream = try await FingerStringCLI.controller.getAllTasksStream(on: .list(list.id))

		var index = 0
		for try await (_, task) in itemsStream {
			try await printItem(task)
			index += 1
		}

		if index == 0 {
			print("(empty)")
		}
	}

	private func printItem(
		_ item: TaskItem,
		indent: String = ""
	) async throws {
		guard
			item.isComplete == false || showCompletedTasks
		else { return }

		let note: String? = {
			guard let note = item.note else { return nil }
			if showNotes {
				return "\n\(note.prefixingLines(with: indent + "\t"))"
			} else {
				return "(*)"
			}
		}()

		let lineBuilder: [String?] = [
			["[", item.isComplete ? "x" : " ", "]"].joined(),
			"[\(item.itemHashId)]",
			"\(item.label)",
			note
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
