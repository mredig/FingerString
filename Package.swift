// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "FingerString",
	platforms: [
		.macOS(.v13),
	],
	products: [
		.library(
			name: "FingerStringLib",
			targets: ["FingerStringLib"]
		),
		.executable(
			name: "fingerstring",
			targets: ["FingerStringCLI"]
		),
	],

	dependencies: [
		.package(
			url: "https://github.com/Lighter-swift/Lighter.git",
			from: "1.0.0"
		),
		.package(
			url: "https://github.com/mredig/SwiftPizzaSnips.git",
			branch: "0.4.38i"
		),
		.package(
			url: "https://github.com/apple/swift-argument-parser.git",
			from: "1.3.0"
		),
	],
	targets: [
		.target(
			name: "FingerStringLib",
			dependencies: [
				.product(name: "Lighter", package: "Lighter"),
				"SwiftPizzaSnips"
			],
			swiftSettings: [
				.enableUpcomingFeature("StrictConcurrency"),
			]
		),
		.executableTarget(
			name: "FingerStringCLI",
			dependencies: [
				"FingerStringLib",
				.product(name: "ArgumentParser", package: "swift-argument-parser"),
			],
			swiftSettings: [
				.enableUpcomingFeature("StrictConcurrency"),
			]
		),
		.testTarget(
			name: "FingerStringTests",
			dependencies: ["FingerStringLib"]
		),
	]
)
