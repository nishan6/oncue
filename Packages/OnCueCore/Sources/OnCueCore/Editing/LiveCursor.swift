import Foundation

/// Where Live Mode is in the script: a song or segment and the shot on air.
/// `index == -1` means standing by: nothing taken yet, the first shot is next.
/// Stepping is manual (NEXT / back / jump); timing sources drive it once the show engine exists.
public struct LiveCursor: Equatable {
    public var itemID: UUID
    public var index: Int

    public init(itemID: UUID, index: Int = -1) {
        self.itemID = itemID
        self.index = index
    }

    public var isStandingBy: Bool { index < 0 }
}

extension Show {

    public func liveNow(_ cursor: LiveCursor) -> ShotRow? {
        let rows = shotRows(forItem: cursor.itemID)
        return rows.indices.contains(cursor.index) ? rows[cursor.index] : nil
    }

    public func liveNext(_ cursor: LiveCursor) -> ShotRow? {
        let rows = shotRows(forItem: cursor.itemID)
        return rows.indices.contains(cursor.index + 1) ? rows[cursor.index + 1] : nil
    }

    /// The shots after NEXT, up to `limit`.
    public func liveUpcoming(_ cursor: LiveCursor, limit: Int) -> [ShotRow] {
        let rows = shotRows(forItem: cursor.itemID)
        let start = cursor.index + 2
        guard start < rows.count else { return [] }
        return Array(rows[start..<min(rows.count, start + limit)])
    }

    /// NEXT: takes the next shot. Returns false at the end of the song or segment.
    @discardableResult
    public func advance(_ cursor: inout LiveCursor) -> Bool {
        guard cursor.index + 1 < shotRows(forItem: cursor.itemID).count else { return false }
        cursor.index += 1
        return true
    }

    /// Back one shot (to standing by from the first shot).
    @discardableResult
    public func stepBack(_ cursor: inout LiveCursor) -> Bool {
        guard cursor.index >= 0 else { return false }
        cursor.index -= 1
        return true
    }

    /// Takes the first shot of a section.
    @discardableResult
    public func jump(_ cursor: inout LiveCursor, toSection sectionID: UUID) -> Bool {
        guard let k = shotRows(forItem: cursor.itemID).firstIndex(where: { $0.sectionID == sectionID }) else { return false }
        cursor.index = k
        return true
    }

    /// Moves to the previous or next song or segment, standing by on its first shot.
    @discardableResult
    public func moveItem(_ cursor: inout LiveCursor, by delta: Int) -> Bool {
        guard let i = itemIndex(cursor.itemID) else { return false }
        let target = i + delta
        guard items.indices.contains(target) else { return false }
        cursor = LiveCursor(itemID: items[target].id)
        return true
    }
}
