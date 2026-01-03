//
//  ListAll.swift
//  FingerString
//
//  Created by Michael Redig on 1/2/26.
//


import ArgumentParser
import FingerStringLib
import Foundation

struct ListAll: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "list-all",
		abstract: "List all lists"
	)

	func run() async throws {
//		let db = try await FingerStringDatabase.create()
//		let lists = try await db.getAllLists()
//
//		if lists.isEmpty {
//			print("No lists found")
//			return
//		}
//
//		print("📚 Task Lists:")
//		for list in lists {
//			print("  • \(list.slug)", terminator: "")
//			if let title = list.title {
//				print(" - \(title)", terminator: "")
//			}
//			print()
//		}
	}
}