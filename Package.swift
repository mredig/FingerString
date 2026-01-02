// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "FingerString",
	platforms: [
		.macOS(.v10_15),
	],
	products: [
		.library(
			name: "FingerString",
			targets: ["FingerString"]
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
			url: "https://github.com/apple/swift-argument-parser.git",
			from: "1.3.0"
		),
	],
	targets: [
		.target(
			name: "FingerString",
			dependencies: [
				.product(name: "Lighter", package: "Lighter"),
			],
			swiftSettings: [
				.enableUpcomingFeature("StrictConcurrency"),
			]
		),
		.executableTarget(
			name: "FingerStringCLI",
			dependencies: [
				"FingerString",
				.product(name: "ArgumentParser", package: "swift-argument-parser"),
			],
			swiftSettings: [
				.enableUpcomingFeature("StrictConcurrency"),
			]
		),
		.testTarget(
			name: "FingerStringTests",
			dependencies: ["FingerString"]
		),
	]
)
