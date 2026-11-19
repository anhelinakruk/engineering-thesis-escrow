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
        // Real text from Sepolia when the amount plus fee exceeds the balance.
        XCTAssertEqual(
            AlloyEscrowService.reason(.ProviderError(message: "server returned an error response: error code -32003: EVM error: OutOfFunds")),
            "Not enough ETH in your wallet to cover this amount plus the network fee."
        )
        // Real text from Rust when the RPC node is down or unresolvable.
        XCTAssertEqual(
            AlloyEscrowService.reason(.ProviderError(message: "error sending request for url (http://127.0.0.1:8545/)")),
            "Can't reach the Ethereum network. Check your internet connection and try again."
        )
    }

    func testInviteURLCarriesKey() {
        var escrow = Escrow(id: 7, buyer: "0xabc", seller: nil, amountWei: "1",
                            state: .funded, shipDeadline: nil, confirmDeadline: nil)
        XCTAssertEqual(escrow.inviteURL.absoluteString, "escrow://join/7")

        escrow.inviteKey = "qMJaOZ9PBqPgVj5j4"
        let url = escrow.inviteURL
        XCTAssertEqual(url.absoluteString, "escrow://join/7?k=qMJaOZ9PBqPgVj5j4")
        XCTAssertEqual(url.host, "join")
        XCTAssertEqual(url.lastPathComponent, "7")
    }
}
