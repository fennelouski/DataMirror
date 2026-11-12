//
//  ColumnFlowTests.swift
//  DataMirrorTests
//

import CoreGraphics
import Testing
@testable import DataMirror

/// The external display cannot scroll, so the column split decides what is visible.
struct ColumnFlowTests {

    @Test func equalCardsSplitEvenly() {
        let columns = ColumnFlow.balance(Array(repeating: 50, count: 6), into: 3, spacing: 10)
        #expect(columns == [[0, 1], [2, 3], [4, 5]])
    }

    @Test func everyCardIsPlacedOnceInReadingOrder() {
        let heights: [CGFloat] = [100, 40, 60, 120, 30, 80, 15]
        for count in 1...5 {
            let columns = ColumnFlow.balance(heights, into: count, spacing: 12)
            #expect(columns.flatMap { $0 } == Array(heights.indices))
            #expect(columns.count <= count)
            #expect(!columns.contains { $0.isEmpty })
        }
    }

    @Test func fewCardsDoNotInventColumns() {
        #expect(ColumnFlow.balance([200], into: 4, spacing: 12) == [[0]])
        #expect(ColumnFlow.balance([], into: 4, spacing: 12) == [[]])
    }
}
