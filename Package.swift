// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TiredApp",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "TiredApp",
            targets: ["TiredApp"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.19.0")
    ],
    targets: [
        .target(
            name: "TiredApp",
            dependencies: [
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseStorage", package: "firebase-ios-sdk")
            ],
            path: "TiredApp"
        )
    ]
)
