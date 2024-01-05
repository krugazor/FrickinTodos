// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FrickinTodo",
    dependencies: [
        .package(url: "https://github.com/krugazor/swift-html-kitura.git", from: "0.3.0"),
        .package(url: "https://github.com/Kitura/Kitura.git", from: "2.9.0"),
        .package(url: "https://github.com/Kitura/Kitura-Session.git", from: "3.3.0"),
        .package(url: "https://github.com/Kitura/Kitura-Session-Redis", from: "2.1.0"),
        .package(url: "https://github.com/Kitura/Kitura-Compression.git", from: "2.2.0"),
        .package(url: "https://github.com/Kitura/HeliumLogger", from: "1.9.0"),
        .package(url: "https://github.com/krugazor/DictionaryCoding", from: "0.0.0"),
        //        .package(url: "https://github.com/IBM-Swift/Swift-Kuery-SQLite.git", from: "2.0.0")
        .package(url: "https://github.com/krugazor/Kitura-Translation", from: "0.1.0"),
        .package(url: "https://github.com/krugazor/Kitura-LanguageNegotiation", from: "0.1.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "FrickinTodo",
            //            dependencies: ["HtmlKituraSupport", "KituraSessionRedis", "KituraSession", "SwiftKuerySQLite"]),
            dependencies: ["Kitura", "HtmlKituraSupport", "KituraSessionRedis", "KituraSession", "KituraCompression", "HeliumLogger",
                           "DictionaryCoding", "KituraTranslation", "KituraLangNeg"]),
        .testTarget(
            name: "FrickinTodoTests",
            dependencies: ["FrickinTodo"]),
    ]
)
