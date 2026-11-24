import Testing
@testable import Shove95Kit

@Suite("Bucket line stepping")
struct BucketSteppingTests {
    @Test func deferSteps() {
        #expect(Bucket.today.steppedOnce(.deferOne) == .tomorrow)
        #expect(Bucket.tomorrow.steppedOnce(.deferOne) == .general)
    }

    @Test func pullSteps() {
        #expect(Bucket.general.steppedOnce(.pullOne) == .tomorrow)
        #expect(Bucket.tomorrow.steppedOnce(.pullOne) == .today)
    }

    @Test func deadEnds() {
        #expect(Bucket.today.steppedOnce(.pullOne) == nil)     // nothing nearer than today
        #expect(Bucket.general.steppedOnce(.deferOne) == nil)  // nothing beyond the parking lot
    }

    @Test func lineOrder() {
        #expect(Bucket.line == [.today, .tomorrow, .general])
    }
}

@Suite("Context-menu destinations (locked PRD §3 table)")
struct BucketMenuTests {
    @Test func todayMenu() {
        #expect(Bucket.today.menuDestinations == [
            .init(label: ">> Soon", bucket: .general),
        ])
    }

    /// Empty on purpose: with Week gone, Tomorrow's only two neighbours are
    /// both one swipe away, and the menu lists only what a swipe cannot reach.
    @Test func tomorrowMenu() {
        #expect(Bucket.tomorrow.menuDestinations.isEmpty)
    }

    @Test func generalMenu() {
        #expect(Bucket.general.menuDestinations == [
            .init(label: "<< Today", bucket: .today),
        ])
    }

    @Test("menus never contain adjacent buckets or self")
    func noAdjacentDestinations() {
        for bucket in Bucket.line {
            let adjacent = [bucket.steppedOnce(.deferOne), bucket.steppedOnce(.pullOne)]
            for dest in bucket.menuDestinations {
                #expect(dest.bucket != bucket)
                #expect(!adjacent.contains(dest.bucket))
            }
        }
    }
}
