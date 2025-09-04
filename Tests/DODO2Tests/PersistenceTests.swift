import XCTest
@testable import DODO2

final class PersistenceTests: XCTestCase {
    func testDragDropDecode() {
        let id = UUID()
        XCTAssertEqual(DragDropPayload.taskId(from: "task:\(id.uuidString)"), id)
        XCTAssertNil(DragDropPayload.taskId(from: "tsk:\(id.uuidString)"))
        XCTAssertNil(DragDropPayload.taskId(from: "task:not-a-uuid"))
    }

    func testPersistenceRoundTrip() throws {
        var store = Store(tasks: [], labels: [Label(id: "g", name: "General", color: .gray)])
        store.tasks = [Task(title: "Hello", done: false, labelId: "g")]
        Persistence.save(store, immediate: true)
        let loaded = Persistence.load()
        XCTAssertTrue(loaded.tasks.contains(where: { $0.title == "Hello" && $0.labelId == "g" }))
    }
}

