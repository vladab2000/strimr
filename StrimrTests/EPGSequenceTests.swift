import Foundation
import Testing
@testable import Strimr_macOS

@MainActor
struct EPGSequenceTests {
    let today = Fixtures.utcDay(2026, 11, 7)
    let offset = 250

    private func day(_ delta: Int) -> Date {
        today.addingTimeInterval(TimeInterval(delta * 86400))
    }

    private func programs(_ prefix: String, on date: Date, count: Int) -> [Media] {
        (0..<count).map { Fixtures.program("\(prefix)\($0)", start: date.addingTimeInterval(TimeInterval($0 * 3600))) }
    }

    @Test func todayStartsAtOffsetHistoryGoesBackwards() {
        let cache = [today: programs("d0-", on: today, count: 3), day(-1): programs("d1-", on: day(-1), count: 2)]
        let sequence = ChannelManager.buildSequence(from: cache, today: today, todayIndexOffset: offset)

        #expect(sequence[offset]?.name == "d0-0")
        #expect(sequence[offset + 2]?.name == "d0-2")
        #expect(sequence[offset + 3] == nil)
        // Včerejšek končí těsně před dneškem
        #expect(sequence[offset - 1]?.name == "d1-1")
        #expect(sequence[offset - 2]?.name == "d1-0")
    }

    @Test func programAcrossMidnightAppearsOnce() {
        let crossing = Fixtures.program("pres-pulnoc", start: today.addingTimeInterval(-1800), minutes: 60)
        let cache = [
            day(-1): programs("d1-", on: day(-1), count: 1) + [crossing],
            today: [crossing] + programs("d0-", on: today.addingTimeInterval(3600), count: 1),
        ]
        let sequence = ChannelManager.buildSequence(from: cache, today: today, todayIndexOffset: offset)
        #expect(sequence.compactMap { $0 }.filter { $0.name == "pres-pulnoc" }.count == 1)
    }

    /// Chybějící den mezi dneškem a starším dnem: starší den se zařadí hned za dnešek a po dočtení
    /// chybějícího dne se posune — proto si EPG pamatuje fokus podle pořadu, ne podle indexu
    @Test func laterLoadedDayShiftsOlderPrograms() {
        let twoDaysAgo = programs("d2-", on: day(-2), count: 2)
        let before = ChannelManager.buildSequence(from: [day(-2): twoDaysAgo], today: today, todayIndexOffset: offset)
        let after = ChannelManager.buildSequence(
            from: [day(-2): twoDaysAgo, day(-1): programs("d1-", on: day(-1), count: 3)],
            today: today, todayIndexOffset: offset,
        )
        #expect(before[offset - 1]?.name == "d2-1")
        #expect(after[offset - 1]?.name == "d1-2")
        #expect(after.firstIndex { $0?.name == "d2-1" } == offset - 4)
    }
}
