import Foundation

public enum Constants {
	public static let defaultDBURL = URL
		.homeDirectory
		.appending(path: ".config")
		.appending(path: "FingerString")
		.appending(path: "store")
		.appendingPathExtension("db")

	// This cannot ever change as the db format relies on this length
	public static let hashIDLength = 5
}
