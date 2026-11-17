//
//  escrowTests.swift
//  escrowTests
//
//  Created by Anhelina  on 21/06/2026.
//

import XCTest
import AlloySwift
@testable import escrow

final class escrowTests: XCTestCase {

    func testWeiFromEth() {
        XCTAssertEqual(Wei.from(eth: "1"), "1000000000000000000")
        XCTAssertEqual(Wei.from(eth: "0.5"), "500000000000000000")
        XCTAssertEqual(Wei.from(eth: "0,82"), "820000000000000000")
        XCTAssertEqual(Wei.from(eth: "0.000000000000000001"), "1")
        XCTAssertEqual(Wei.from(eth: "123456.123456789012345678"), "123456123456789012345678")
        XCTAssertNil(Wei.from(eth: ""))
        XCTAssertNil(Wei.from(eth: "0"))
        XCTAssertNil(Wei.from(eth: "-1"))
        XCTAssertNil(Wei.from(eth: "abc"))
        XCTAssertNil(Wei.from(eth: "0.0000000000000000001"))
    }

    func testWeiToEth() {
        XCTAssertEqual(Wei.toEth("500000000000000000"), Decimal(string: "0.5"))
        XCTAssertEqual(Wei.toEth("0"), 0)
    }

    func testRevertReasonIsExtracted() {
        let error = AlloyError.ProviderError(
            message: "server returned an error response: error code 3: execution reverted: only buyer can confirm, data: \"0x08c3\""
        )
        XCTAssertEqual(AlloyEscrowService.reason(error), "only buyer can confirm")
        XCTAssertEqual(AlloyEscrowService.reason(.UrlError(message: "bad url")), "bad url")
    }
}
