//
//  ItemDelete.swift
//  FingerString
//
//  Created by Michael Redig on 1/2/26.
//


import ArgumentParser
import FingerStringLib
import Foundation

struct ItemDelete: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "item-delete",
		abstract: "Delete an item"
	)

	@Argument(help: "ID of the item to delete")
	var itemID: Int64

	@Flag(help: "Skip confirmation")
	var force: Bool = false

	func run() async throws {
//		if !force {
//			print("Delete item? (yes/no)")
//			guard let input = readLine(),
//				  input.lowercased() == "yes" else {
//				print("Cancelled")
//				return
//			}
//		}
//
//		let db = try await FingerStringDatabase.create()
//		try await db.deleteItem(id: itemID)
//		print("Deleted item")
	}
}