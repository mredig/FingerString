import ArgumentParser
import FingerStringLib
import Foundation

struct ListView: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "list-view",
		abstract: "View a list and its items"
	)

	@Argument(help: "Slug of the list to view")
	var slug: String

	@Flag
	var showCompletedTasks: Bool = false

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

		let itemsStream = try await FingerStringCLI.controller.getAllTasksStream(on: list.id)

		var index = 0
		for try await (_, task) in itemsStream {
			printItem(task)
			index += 1
		}

		if index == 0 {
			print("(empty)")
		}
	}

	private func printItem(
		_ item: TaskItem,
		indent: String = ""
	) {
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
	}
}
