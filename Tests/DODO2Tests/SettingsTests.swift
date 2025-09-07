import XCTest
import Carbon.HIToolbox
@testable import DODO2

final class SettingsTests: XCTestCase {
    func testLabelOrderPersistence() {
        var store = Persistence.load()
        let original = store.labels
        guard original.count >= 2 else { return }
        var reordered = original
        let moved = reordered.remove(at: 0)
        reordered.append(moved)
        store.labels = reordered
        Persistence.save(store, immediate: true)
        let loaded = Persistence.load()
        XCTAssertEqual(loaded.labels.map { $0.id }, reordered.map { $0.id })
    }

    func testShortcutFormatting() {
        let s = KeyDisplay.format(keyCode: UInt32(kVK_Space), modifiers: UInt32(cmdKey | optionKey))
        XCTAssertTrue(s.contains("⌘"))
        XCTAssertTrue(s.contains("⌥"))
        XCTAssertTrue(s.contains("Space"))
    }
}
