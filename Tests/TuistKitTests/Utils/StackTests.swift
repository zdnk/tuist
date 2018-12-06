//
//  StackTests.swift
//  TuistKitTests
//
//  Created by Atkinson, Oliver (Senior Developer) on 06/12/2018.
//

import XCTest
@testable import TuistKit

final class StackTests: XCTestCase {
    
    func testEmpty() {
        var stack = Stack<Int>()
        XCTAssertTrue(stack.isEmpty)
        XCTAssertEqual(stack.count, 0)
        XCTAssertNil(stack.pop())
    }
    
    func testOneElement() {
        var stack = Stack<Int>()
        
        stack.push(123)
        XCTAssertFalse(stack.isEmpty)
        XCTAssertEqual(stack.count, 1)
        
        let result = stack.pop()
        XCTAssertEqual(result, 123)
        XCTAssertTrue(stack.isEmpty)
        XCTAssertEqual(stack.count, 0)
        XCTAssertNil(stack.pop())
    }
    
    func testTwoElements() {
        var stack = Stack<Int>()
        
        stack.push(123)
        stack.push(456)
        XCTAssertFalse(stack.isEmpty)
        XCTAssertEqual(stack.count, 2)
        
        let result1 = stack.pop()
        XCTAssertEqual(result1, 456)
        XCTAssertFalse(stack.isEmpty)
        XCTAssertEqual(stack.count, 1)
        
        let result2 = stack.pop()
        XCTAssertEqual(result2, 123)
        XCTAssertTrue(stack.isEmpty)
        XCTAssertEqual(stack.count, 0)
        XCTAssertNil(stack.pop())
    }
    
    func testMakeEmpty() {
        var stack = Stack<Int>()
        
        stack.push(123)
        stack.push(456)
        XCTAssertNotNil(stack.pop())
        XCTAssertNotNil(stack.pop())
        XCTAssertNil(stack.pop())
        
        stack.push(789)
        XCTAssertEqual(stack.count, 1)
        
        let result = stack.pop()
        XCTAssertEqual(result, 789)
        XCTAssertTrue(stack.isEmpty)
        XCTAssertEqual(stack.count, 0)
        XCTAssertNil(stack.pop())
    }
    
}
