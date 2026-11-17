// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Escrow} from "../src/Escrow.sol";

contract EscrowTest is Test {
    Escrow escrow;

    address arbiter = makeAddr("arbiter");
    address buyer = makeAddr("buyer");
    address seller = makeAddr("seller");
    address stranger = makeAddr("stranger");

    uint256 constant AMOUNT = 1 ether;

    function setUp() public {
        escrow = new Escrow(arbiter);
        vm.deal(buyer, 100 ether);
        vm.deal(seller, 100 ether);
        vm.deal(stranger, 100 ether);
        vm.deal(arbiter, 100 ether);
    }

    // ---------------------------------------------------------------- helpers

    function _tx(uint256 id) internal view returns (Escrow.Transaction memory t) {
        (t.buyer, t.seller, t.amount, t.state, t.shipDeadline, t.confirmDeadline) = escrow.transactions(id);
    }

    function _created() internal returns (uint256 id) {
        vm.prank(buyer);
        id = escrow.createEscrow{value: AMOUNT}();
    }

    function _joined() internal returns (uint256 id) {
        id = _created();
        vm.prank(seller);
        escrow.joinEscrow(id);
    }

    function _shipped() internal returns (uint256 id) {
        id = _joined();
        vm.prank(seller);
        escrow.markShipped(id);
    }

    function _disputed() internal returns (uint256 id) {
        id = _shipped();
        vm.prank(buyer);
        escrow.raiseDispute(id);
    }

    // ------------------------------------------------------------ constructor

    function test_constructor_setsArbiter() public view {
        assertEq(escrow.arbiter(), arbiter);
    }

    function test_constructor_revertsOnZeroArbiter() public {
        vm.expectRevert("arbiter is zero address");
        new Escrow(address(0));
    }

    // ----------------------------------------------------------- createEscrow

    function test_createEscrow_fundsAndStoresDeal() public {
        vm.expectEmit(true, true, false, true);
        emit Escrow.EscrowCreated(0, buyer, AMOUNT);

        uint256 id = _created();

        Escrow.Transaction memory t = _tx(id);
        assertEq(id, 0);
        assertEq(escrow.nextId(), 1);
        assertEq(t.buyer, buyer);
        assertEq(t.seller, address(0));
        assertEq(t.amount, AMOUNT);
        assertEq(uint8(t.state), uint8(Escrow.State.Funded));
        assertEq(t.shipDeadline, block.timestamp + escrow.SHIP_TIMEOUT());
        assertEq(t.confirmDeadline, 0);
        assertEq(address(escrow).balance, AMOUNT);
    }

    function test_createEscrow_incrementsIds() public {
        assertEq(_created(), 0);
        assertEq(_created(), 1);
        assertEq(escrow.nextId(), 2);
    }

    function test_createEscrow_revertsOnZeroValue() public {
        vm.prank(buyer);
        vm.expectRevert("amount must be positive");
        escrow.createEscrow{value: 0}();
    }

    function test_createEscrow_revertsForArbiter() public {
        vm.prank(arbiter);
        vm.expectRevert("arbiter cannot be a party");
        escrow.createEscrow{value: AMOUNT}();
    }

    // ------------------------------------------------------------- joinEscrow

    function test_joinEscrow_setsSeller() public {
        uint256 id = _created();

        vm.expectEmit(true, true, false, false);
        emit Escrow.SellerJoined(id, seller);
        vm.prank(seller);
        escrow.joinEscrow(id);

        Escrow.Transaction memory t = _tx(id);
        assertEq(t.seller, seller);
        assertEq(uint8(t.state), uint8(Escrow.State.Funded));
    }

    function test_joinEscrow_revertsWhenMissing() public {
        vm.prank(seller);
        vm.expectRevert("escrow does not exist");
        escrow.joinEscrow(0);
    }

    function test_joinEscrow_revertsWhenAlreadyJoined() public {
        uint256 id = _joined();
        vm.prank(stranger);
        vm.expectRevert("seller already joined");
        escrow.joinEscrow(id);
    }

    function test_joinEscrow_revertsForBuyer() public {
        uint256 id = _created();
        vm.prank(buyer);
        vm.expectRevert("buyer cannot be seller");
        escrow.joinEscrow(id);
    }

    function test_joinEscrow_revertsForArbiter() public {
        uint256 id = _created();
        vm.prank(arbiter);
        vm.expectRevert("arbiter cannot be a party");
        escrow.joinEscrow(id);
    }

    function test_joinEscrow_revertsWhenNotFunded() public {
        uint256 id = _created();
        vm.prank(buyer);
        escrow.cancelEscrow(id);

        vm.prank(seller);
        vm.expectRevert("escrow not joinable");
        escrow.joinEscrow(id);
    }

    // ----------------------------------------------------------- cancelEscrow

    function test_cancelEscrow_refundsBuyer() public {
        uint256 id = _created();

        vm.expectEmit(true, false, false, false);
        emit Escrow.EscrowRefunded(id);
        vm.prank(buyer);
        escrow.cancelEscrow(id);

        assertEq(uint8(_tx(id).state), uint8(Escrow.State.Refunded));
        assertEq(escrow.pendingWithdrawals(buyer), AMOUNT);
    }

    function test_cancelEscrow_revertsWhenMissing() public {
        vm.prank(buyer);
        vm.expectRevert("escrow does not exist");
        escrow.cancelEscrow(0);
    }

    function test_cancelEscrow_revertsForNonBuyer() public {
        uint256 id = _created();
        vm.prank(stranger);
        vm.expectRevert("only buyer can cancel");
        escrow.cancelEscrow(id);
    }

    function test_cancelEscrow_revertsAfterSellerJoined() public {
        uint256 id = _joined();
        vm.prank(buyer);
        vm.expectRevert("seller already joined");
        escrow.cancelEscrow(id);
    }

    function test_cancelEscrow_revertsWhenNotFunded() public {
        uint256 id = _created();
        vm.startPrank(buyer);
        escrow.cancelEscrow(id);
        vm.expectRevert("escrow not in Funded state");
        escrow.cancelEscrow(id);
        vm.stopPrank();
    }

    // ------------------------------------------------------------ markShipped

    function test_markShipped_startsConfirmTimeout() public {
        uint256 id = _joined();
        uint256 expected = block.timestamp + escrow.CONFIRM_TIMEOUT();

        vm.expectEmit(true, false, false, true);
        emit Escrow.ItemShipped(id, expected);
        vm.prank(seller);
        escrow.markShipped(id);

        Escrow.Transaction memory t = _tx(id);
        assertEq(uint8(t.state), uint8(Escrow.State.Shipped));
        assertEq(t.confirmDeadline, expected);
    }

    function test_markShipped_revertsWhenMissing() public {
        vm.prank(seller);
        vm.expectRevert("escrow does not exist");
        escrow.markShipped(0);
    }

    function test_markShipped_revertsForNonSeller() public {
        uint256 id = _joined();
        vm.prank(buyer);
        vm.expectRevert("only seller can ship");
        escrow.markShipped(id);
    }

    function test_markShipped_revertsBeforeSellerJoined() public {
        uint256 id = _created();
        vm.prank(seller);
        vm.expectRevert("only seller can ship");
        escrow.markShipped(id);
    }

    function test_markShipped_revertsWhenAlreadyShipped() public {
        uint256 id = _shipped();
        vm.prank(seller);
        vm.expectRevert("escrow not in Funded state");
        escrow.markShipped(id);
    }

    // --------------------------------------------------------- confirmReceipt

    function test_confirmReceipt_paysSeller() public {
        uint256 id = _shipped();

        vm.expectEmit(true, false, false, false);
        emit Escrow.EscrowCompleted(id);
        vm.prank(buyer);
        escrow.confirmReceipt(id);

        assertEq(uint8(_tx(id).state), uint8(Escrow.State.Completed));
        assertEq(escrow.pendingWithdrawals(seller), AMOUNT);
        assertEq(escrow.pendingWithdrawals(buyer), 0);
    }

    function test_confirmReceipt_revertsWhenMissing() public {
        vm.prank(buyer);
        vm.expectRevert("escrow does not exist");
        escrow.confirmReceipt(0);
    }

    function test_confirmReceipt_revertsForNonBuyer() public {
        uint256 id = _shipped();
        vm.prank(seller);
        vm.expectRevert("only buyer can confirm");
        escrow.confirmReceipt(id);
    }

    function test_confirmReceipt_revertsWhenNotShipped() public {
        uint256 id = _joined();
        vm.prank(buyer);
        vm.expectRevert("escrow not in Shipped state");
        escrow.confirmReceipt(id);
    }

    // ---------------------------------------------------------- refundExpired

    function test_refundExpired_refundsAtDeadline() public {
        uint256 id = _joined();
        vm.warp(_tx(id).shipDeadline);

        vm.expectEmit(true, false, false, false);
        emit Escrow.EscrowRefunded(id);
        vm.prank(buyer);
        escrow.refundExpired(id);

        assertEq(uint8(_tx(id).state), uint8(Escrow.State.Refunded));
        assertEq(escrow.pendingWithdrawals(buyer), AMOUNT);
    }

    function test_refundExpired_revertsBeforeDeadline() public {
        uint256 id = _joined();
        vm.warp(_tx(id).shipDeadline - 1);
        vm.prank(buyer);
        vm.expectRevert("ship deadline not reached");
        escrow.refundExpired(id);
    }

    function test_refundExpired_revertsWhenMissing() public {
        vm.prank(buyer);
        vm.expectRevert("escrow does not exist");
        escrow.refundExpired(0);
    }

    function test_refundExpired_revertsForNonBuyer() public {
        uint256 id = _joined();
        vm.warp(_tx(id).shipDeadline);
        vm.prank(seller);
        vm.expectRevert("only buyer can claim refund");
        escrow.refundExpired(id);
    }

    function test_refundExpired_revertsAfterShipped() public {
        uint256 id = _shipped();
        vm.warp(_tx(id).shipDeadline);
        vm.prank(buyer);
        vm.expectRevert("escrow not in Funded state");
        escrow.refundExpired(id);
    }

    // ----------------------------------------------------------- autoComplete

    function test_autoComplete_paysSellerAtDeadline() public {
        uint256 id = _shipped();
        vm.warp(_tx(id).confirmDeadline);

        vm.expectEmit(true, false, false, false);
        emit Escrow.EscrowCompleted(id);
        vm.prank(seller);
        escrow.autoComplete(id);

        assertEq(uint8(_tx(id).state), uint8(Escrow.State.Completed));
        assertEq(escrow.pendingWithdrawals(seller), AMOUNT);
    }

    function test_autoComplete_revertsBeforeDeadline() public {
        uint256 id = _shipped();
        vm.warp(_tx(id).confirmDeadline - 1);
        vm.prank(seller);
        vm.expectRevert("confirm deadline not reached");
        escrow.autoComplete(id);
    }

    function test_autoComplete_revertsWhenMissing() public {
        vm.prank(seller);
        vm.expectRevert("escrow does not exist");
        escrow.autoComplete(0);
    }

    function test_autoComplete_revertsForNonSeller() public {
        uint256 id = _shipped();
        vm.warp(_tx(id).confirmDeadline);
        vm.prank(buyer);
        vm.expectRevert("only seller can auto-complete");
        escrow.autoComplete(id);
    }

    function test_autoComplete_revertsWhenDisputed() public {
        uint256 id = _disputed();
        vm.warp(_tx(id).confirmDeadline);
        vm.prank(seller);
        vm.expectRevert("escrow not in Shipped state");
        escrow.autoComplete(id);
    }

    // ----------------------------------------------------------- raiseDispute

    function test_raiseDispute_byBuyer() public {
        uint256 id = _shipped();

        vm.expectEmit(true, true, false, false);
        emit Escrow.DisputeRaised(id, buyer);
        vm.prank(buyer);
        escrow.raiseDispute(id);

        assertEq(uint8(_tx(id).state), uint8(Escrow.State.Disputed));
    }

    function test_raiseDispute_bySeller() public {
        uint256 id = _shipped();

        vm.expectEmit(true, true, false, false);
        emit Escrow.DisputeRaised(id, seller);
        vm.prank(seller);
        escrow.raiseDispute(id);

        assertEq(uint8(_tx(id).state), uint8(Escrow.State.Disputed));
    }

    function test_raiseDispute_revertsWhenMissing() public {
        vm.prank(buyer);
        vm.expectRevert("escrow does not exist");
        escrow.raiseDispute(0);
    }

    function test_raiseDispute_revertsForStranger() public {
        uint256 id = _shipped();
        vm.prank(stranger);
        vm.expectRevert("only parties can dispute");
        escrow.raiseDispute(id);
    }

    function test_raiseDispute_revertsForArbiter() public {
        uint256 id = _shipped();
        vm.prank(arbiter);
        vm.expectRevert("only parties can dispute");
        escrow.raiseDispute(id);
    }

    function test_raiseDispute_revertsBeforeShipped() public {
        uint256 id = _joined();
        vm.prank(buyer);
        vm.expectRevert("dispute only from Shipped");
        escrow.raiseDispute(id);
    }

    function test_raiseDispute_revertsAfterCompleted() public {
        uint256 id = _shipped();
        vm.startPrank(buyer);
        escrow.confirmReceipt(id);
        vm.expectRevert("dispute only from Shipped");
        escrow.raiseDispute(id);
        vm.stopPrank();
    }

    // ---------------------------------------------------------------- resolve

    function test_resolveForSeller_paysSeller() public {
        uint256 id = _disputed();

        vm.expectEmit(true, false, false, false);
        emit Escrow.EscrowCompleted(id);
        vm.prank(arbiter);
        escrow.resolveForSeller(id);

        assertEq(uint8(_tx(id).state), uint8(Escrow.State.Completed));
        assertEq(escrow.pendingWithdrawals(seller), AMOUNT);
        assertEq(escrow.pendingWithdrawals(arbiter), 0);
    }

    function test_resolveForBuyer_refundsBuyer() public {
        uint256 id = _disputed();

        vm.expectEmit(true, false, false, false);
        emit Escrow.EscrowRefunded(id);
        vm.prank(arbiter);
        escrow.resolveForBuyer(id);

        assertEq(uint8(_tx(id).state), uint8(Escrow.State.Refunded));
        assertEq(escrow.pendingWithdrawals(buyer), AMOUNT);
        assertEq(escrow.pendingWithdrawals(arbiter), 0);
    }

    function test_resolve_revertsWhenMissing() public {
        vm.startPrank(arbiter);
        vm.expectRevert("escrow does not exist");
        escrow.resolveForSeller(0);
        vm.expectRevert("escrow does not exist");
        escrow.resolveForBuyer(0);
        vm.stopPrank();
    }

    function test_resolve_revertsForParties() public {
        uint256 id = _disputed();

        vm.prank(seller);
        vm.expectRevert("only arbiter can resolve");
        escrow.resolveForSeller(id);

        vm.prank(buyer);
        vm.expectRevert("only arbiter can resolve");
        escrow.resolveForBuyer(id);
    }

    function test_resolve_revertsWhenNotDisputed() public {
        uint256 id = _shipped();
        vm.startPrank(arbiter);
        vm.expectRevert("escrow not disputed");
        escrow.resolveForSeller(id);
        vm.expectRevert("escrow not disputed");
        escrow.resolveForBuyer(id);
        vm.stopPrank();
    }

    function test_resolve_cannotRunTwice() public {
        uint256 id = _disputed();
        vm.startPrank(arbiter);
        escrow.resolveForSeller(id);
        vm.expectRevert("escrow not disputed");
        escrow.resolveForBuyer(id);
        vm.stopPrank();
    }

    // --------------------------------------------------------------- withdraw

    function test_withdraw_transfersOwedBalance() public {
        uint256 id = _shipped();
        vm.prank(buyer);
        escrow.confirmReceipt(id);

        uint256 before = seller.balance;
        vm.expectEmit(true, false, false, true);
        emit Escrow.Withdrawn(seller, AMOUNT);
        vm.prank(seller);
        escrow.withdraw();

        assertEq(seller.balance, before + AMOUNT);
        assertEq(escrow.pendingWithdrawals(seller), 0);
        assertEq(address(escrow).balance, 0);
    }

    function test_withdraw_revertsWithNothingOwed() public {
        vm.prank(stranger);
        vm.expectRevert("nothing to withdraw");
        escrow.withdraw();
    }

    function test_withdraw_revertsOnSecondCall() public {
        uint256 id = _created();
        vm.startPrank(buyer);
        escrow.cancelEscrow(id);
        escrow.withdraw();
        vm.expectRevert("nothing to withdraw");
        escrow.withdraw();
        vm.stopPrank();
    }

    function test_withdraw_revertsWhenRecipientRejectsEth() public {
        Rejecter rejecter = new Rejecter(escrow);
        vm.deal(address(rejecter), AMOUNT);
        rejecter.createAndCancel(AMOUNT);

        vm.expectRevert("transfer failed");
        rejecter.withdraw();
        assertEq(escrow.pendingWithdrawals(address(rejecter)), AMOUNT);
    }

    // --------------------------------------------------------------- security

    function test_reentrancy_cannotDrainOtherDeals() public {
        // A victim deal that the attacker must not be able to touch.
        _created();

        Reentrant attacker = new Reentrant(escrow);
        vm.deal(address(attacker), AMOUNT);
        attacker.createAndCancel(AMOUNT);
        attacker.attack();

        assertTrue(attacker.reentryBlocked());
        assertEq(address(attacker).balance, AMOUNT);
        assertEq(address(escrow).balance, AMOUNT);
        assertEq(escrow.pendingWithdrawals(address(attacker)), 0);
    }

    function test_arbiter_cannotCollectFunds() public {
        uint256 a = _disputed();
        uint256 b = _disputed();
        vm.startPrank(arbiter);
        escrow.resolveForSeller(a);
        escrow.resolveForBuyer(b);

        assertEq(escrow.pendingWithdrawals(arbiter), 0);
        vm.expectRevert("nothing to withdraw");
        escrow.withdraw();
        vm.stopPrank();
    }

    function test_balance_matchesOwedPlusLocked() public {
        uint256 completed = _shipped();
        vm.prank(buyer);
        escrow.confirmReceipt(completed);

        uint256 refunded = _created();
        vm.prank(buyer);
        escrow.cancelEscrow(refunded);

        _created(); // funded, no seller
        _shipped(); // shipped
        uint256 disputed = _disputed();
        uint256 resolved = _disputed();
        vm.prank(arbiter);
        escrow.resolveForBuyer(resolved);

        vm.prank(seller);
        escrow.withdraw();

        _assertSolvent();
        assertEq(uint8(_tx(disputed).state), uint8(Escrow.State.Disputed));
    }

    function _assertSolvent() internal view {
        uint256 locked;
        for (uint256 id; id < escrow.nextId(); id++) {
            Escrow.Transaction memory t = _tx(id);
            if (
                t.state == Escrow.State.Funded || t.state == Escrow.State.Shipped
                    || t.state == Escrow.State.Disputed
            ) {
                locked += t.amount;
            }
        }
        uint256 owed = escrow.pendingWithdrawals(buyer) + escrow.pendingWithdrawals(seller);
        assertEq(address(escrow).balance, owed + locked);
    }

    // ------------------------------------------------------------------- fuzz

    function testFuzz_happyPath_sellerReceivesExactAmount(uint96 amount) public {
        vm.assume(amount > 0);
        vm.deal(buyer, amount);

        vm.prank(buyer);
        uint256 id = escrow.createEscrow{value: amount}();
        vm.startPrank(seller);
        escrow.joinEscrow(id);
        escrow.markShipped(id);
        vm.stopPrank();
        vm.prank(buyer);
        escrow.confirmReceipt(id);

        uint256 before = seller.balance;
        vm.prank(seller);
        escrow.withdraw();

        assertEq(seller.balance - before, amount);
        assertEq(buyer.balance, 0);
        assertEq(address(escrow).balance, 0);
    }

    function testFuzz_timeouts_respectDeadline(uint256 elapsed) public {
        elapsed = bound(elapsed, 0, 30 days);
        uint256 id = _joined();
        vm.warp(block.timestamp + elapsed);
        uint256 timeout = escrow.SHIP_TIMEOUT();

        vm.prank(buyer);
        if (elapsed < timeout) {
            vm.expectRevert("ship deadline not reached");
            escrow.refundExpired(id);
        } else {
            escrow.refundExpired(id);
            assertEq(escrow.pendingWithdrawals(buyer), AMOUNT);
        }
    }
}

/// Buyer that tries to re-enter withdraw() from its receive hook.
contract Reentrant {
    Escrow immutable escrow;
    bool public reentryBlocked;

    constructor(Escrow _escrow) {
        escrow = _escrow;
    }

    function createAndCancel(uint256 amount) external {
        uint256 id = escrow.createEscrow{value: amount}();
        escrow.cancelEscrow(id);
    }

    function attack() external {
        escrow.withdraw();
    }

    receive() external payable {
        // Swallow the revert so the outer withdraw still succeeds and we can
        // check the attacker got exactly what it was owed, nothing more.
        try escrow.withdraw() {} catch {
            reentryBlocked = true;
        }
    }
}

/// Buyer contract with no receive hook, so every ETH transfer to it fails.
contract Rejecter {
    Escrow immutable escrow;

    constructor(Escrow _escrow) {
        escrow = _escrow;
    }

    function createAndCancel(uint256 amount) external {
        uint256 id = escrow.createEscrow{value: amount}();
        escrow.cancelEscrow(id);
    }

    function withdraw() external {
        escrow.withdraw();
    }
}
