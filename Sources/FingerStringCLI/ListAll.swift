import ArgumentParser
import FingerStringLib
import Foundation

struct ListAll: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "list-all",
		abstract: "List all lists"
	)

	@Flag(help: "Include list descriptions")
	var includeDescriptions: Bool = false

	func run() async throws {
		let controller = await FingerStringCLI.controller
		let lists = try await controller.getAllLists()

		guard lists.isOccupied else {
			print("No lists found")
			return
		}

		for list in lists {
			print(" * \(list.headerTitle)")
			guard includeDescriptions, let description = list.description else { continue }
			print("\t\(description)")
		}
	}
}
