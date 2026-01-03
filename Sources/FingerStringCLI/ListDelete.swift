//
//  ListDelete.swift
//  FingerString
//
//  Created by Michael Redig on 1/2/26.
//


import ArgumentParser
import FingerStringLib
import Foundation

struct ListDelete: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "list-delete",
		abstract: "Delete a list"
	)

	@Argument(help: "Slug of the list to delete")
	var slug: String

	@Flag(help: "Skip confirmation")
	var force: Bool = false

	func run() async throws {
//		if !force {
//			print("Delete list '\(slug)'? (yes/no)")
//			guard let input = readLine(),
//				  input.lowercased() == "yes" else {
//				print("Cancelled")
//				return
//			}
//		}
//
//		let db = try await FingerStringDatabase.create()
//		try await db.deleteList(slug: slug)
//		print("Deleted list '\(slug)'")
	}
}