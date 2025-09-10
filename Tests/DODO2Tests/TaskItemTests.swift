import XCTest
@testable import DODO2

final class TaskItemTests: XCTestCase {
    func testQuadrantMapping() throws {
        XCTAssertEqual(TaskItem(title: "A", notes: nil, urgency: 3, importance: 3).quadrant, .doFirst)
        XCTAssertEqual(TaskItem(title: "B", notes: nil, urgency: 1, importance: 2).quadrant, .schedule)
        XCTAssertEqual(TaskItem(title: "C", notes: nil, urgency: 2, importance: 1).quadrant, .delegate)
        XCTAssertEqual(TaskItem(title: "D", notes: nil, urgency: 1, importance: 1).quadrant, .eliminate)
    }

    func testUpdatingClampsAndUpdatesTime() throws {
        var t = TaskItem(title: "E", notes: nil, urgency: 0, importance: 0)
        let old = t.updatedAt
        t = t.updating(urgency: 5, importance: -2) // clamp
        XCTAssertEqual(t.urgency, 3)
        XCTAssertEqual(t.importance, 0)
        XCTAssertGreaterThan(t.updatedAt, old)
    }

    func testBinaryToggleToLevels() throws {
        var t = TaskItem(title: "T", notes: nil, urgency: 1, importance: 1)
        // simulate toggles: OFF->ON sets 3, ON->OFF sets 1
        t = t.updating(importance: 3)
        XCTAssertEqual(t.quadrant, .schedule)
        t = t.updating(urgency: 3)
        XCTAssertEqual(t.quadrant, .doFirst)
        t = t.updating(urgency: 1, importance: 1)
        XCTAssertEqual(t.quadrant, .eliminate)
    }

    func testJSONRoundTrip() throws {
        let items = [
            TaskItem(title: "X", notes: "n", urgency: 2, importance: 2),
            TaskItem(title: "Y", notes: nil, urgency: 1, importance: 3)
        ]
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        let data = try enc.encode(items)
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        let decoded = try dec.decode([TaskItem].self, from: data)
        XCTAssertEqual(decoded.count, 2)
    }
}

