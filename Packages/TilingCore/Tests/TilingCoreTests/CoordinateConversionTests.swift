// SPDX-License-Identifier: GPL-3.0-only

import XCTest
@testable import TilingCore

final class CoordinateConversionTests: XCTestCase {
    private let primaryHeight: CGFloat = 1080

    func testFlipPointIsInvolution() {
        let point = CGPoint(x: 300, y: 200)
        let once = CoordinateConversion.flipY(point, primaryScreenHeight: primaryHeight)
        let twice = CoordinateConversion.flipY(once, primaryScreenHeight: primaryHeight)
        XCTAssertEqual(twice, point)
    }

    func testFlipPointValue() {
        let point = CGPoint(x: 300, y: 200)
        let flipped = CoordinateConversion.flipY(point, primaryScreenHeight: primaryHeight)
        XCTAssertEqual(flipped, CGPoint(x: 300, y: 880))
    }

    func testAXRectFromAppKitTopEdge() {
        // AppKit rect at the top of a 1080 screen: bottom-left origin (0, 880),
        // height 200 → its top is at y=1080. In AX space its top-left is y=0.
        let appKit = CGRect(x: 0, y: 880, width: 400, height: 200)
        let ax = CoordinateConversion.axRect(fromAppKit: appKit, primaryScreenHeight: primaryHeight)
        XCTAssertEqual(ax, CGRect(x: 0, y: 0, width: 400, height: 200))
    }

    func testAXRectRoundTrip() {
        let appKit = CGRect(x: 120, y: 340, width: 500, height: 300)
        let ax = CoordinateConversion.axRect(fromAppKit: appKit, primaryScreenHeight: primaryHeight)
        let back = CoordinateConversion.appKitRect(fromAX: ax, primaryScreenHeight: primaryHeight)
        XCTAssertEqual(back, appKit)
    }

    func testAXRectWithSecondaryScreenAbovePrimary() {
        // A secondary display sitting above the primary produces AppKit y values
        // greater than the primary height; the flip must still round-trip.
        let appKit = CGRect(x: 0, y: 1200, width: 800, height: 600)
        let ax = CoordinateConversion.axRect(fromAppKit: appKit, primaryScreenHeight: primaryHeight)
        // AX y = 1080 - 1200 - 600 = -720 (above the primary, negative in AX space).
        XCTAssertEqual(ax.origin.y, -720, accuracy: 0.001)
        let back = CoordinateConversion.appKitRect(fromAX: ax, primaryScreenHeight: primaryHeight)
        XCTAssertEqual(back, appKit)
    }

    func testAXRectWithNegativeOriginScreen() {
        // A display to the left of the primary has negative x; x is unaffected by
        // the flip and should pass through unchanged.
        let appKit = CGRect(x: -1440, y: 0, width: 1440, height: 900)
        let ax = CoordinateConversion.axRect(fromAppKit: appKit, primaryScreenHeight: primaryHeight)
        XCTAssertEqual(ax.origin.x, -1440, accuracy: 0.001)
        let back = CoordinateConversion.appKitRect(fromAX: ax, primaryScreenHeight: primaryHeight)
        XCTAssertEqual(back, appKit)
    }
}
