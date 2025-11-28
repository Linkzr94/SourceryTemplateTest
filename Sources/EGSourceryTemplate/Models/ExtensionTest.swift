//
//  ExtensionTest.swift
//  EGSourceryTemplate
//
//  测试在 extension 上使用 sourcery 注解
//

// 基础类型定义，不带注解
struct User {
    let id: String
    let username: String
}

// 另一个例子：分离定义
struct Product {
    let productId: String
    let name: String
    let price: Double
}

// 在 extension 上标记 AutoEquatable
// sourcery: AutoEquatable
extension User {
    var displayName: String {
        return "@\(username)"
    }
}

// sourcery: AutoEquatable
extension Product {
    // Extension 中的计算属性不会参与 Equatable 比较
}
