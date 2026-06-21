// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title Escrow — decentralized escrow for peer-to-peer commerce
/// @notice Holds buyer funds until a deal completes, refunds, or is resolved
///         by an arbiter. The contract is the only holder of the funds.
contract Escrow is ReentrancyGuard {
    /// @notice Lifecycle of a single escrow transaction.
    /// Created  → escrow exists, no funds locked yet
    /// Funded   → buyer has deposited the agreed amount
    /// Shipped  → seller marked the item as sent
    /// Completed→ buyer received the item; funds released to seller (terminal)
    /// Disputed → one party raised a dispute; awaits arbiter (only from Shipped)
    /// Refunded → funds returned to buyer (terminal)
    enum State {
        Created,
        Funded,
        Shipped,
        Completed,
        Disputed,
        Refunded
    }

    /// @notice All data describing one escrow deal.
    struct Transaction {
        address buyer;        // who pays and receives the goods
        address seller;       // who ships and receives the funds
        uint256 amount;       // value locked, in wei
        State state;          // current position in the state machine
        uint256 shipDeadline; // by when the seller must ship (set on funding)
        uint256 confirmDeadline; // by when the buyer must confirm (set on shipping)
    }

    /// @notice The dispute resolver. Set once at deployment, cannot move funds
    ///         outside the rules of the state machine.
    address public immutable arbiter;

    /// @notice All escrow deals, keyed by an auto-incrementing id.
    ///         The buyer creates a deal, gets its id, and shares it (in a link)
    ///         with the seller, who joins the same id.
    mapping(uint256 => Transaction) public transactions;

    /// @notice Id assigned to the next created escrow. Starts at 0.
    uint256 public nextId;

    /// @notice ETH each address is owed and may withdraw. Credited when an
    ///         escrow finalizes; drained to zero by withdraw().
    mapping(address => uint256) public pendingWithdrawals;

    /// @notice Window the seller has to ship after the buyer funds the escrow.
    uint256 public constant SHIP_TIMEOUT = 7 days;

    /// @notice Window the buyer has to confirm receipt after the seller ships.
    uint256 public constant CONFIRM_TIMEOUT = 7 days;

    /// @notice Emitted when a buyer creates and funds a new escrow in one step.
    event EscrowCreated(uint256 indexed id, address indexed buyer, uint256 amount);

    /// @notice Emitted when a seller joins an escrow via the shared link.
    event SellerJoined(uint256 indexed id, address indexed seller);

    /// @notice Emitted when the seller marks the item as shipped.
    event ItemShipped(uint256 indexed id, uint256 confirmDeadline);

    /// @notice Emitted when the buyer confirms receipt and the deal completes.
    event EscrowCompleted(uint256 indexed id);

    /// @notice Emitted when the escrow is refunded to the buyer.
    event EscrowRefunded(uint256 indexed id);

    /// @notice Emitted when either party escalates a shipped deal to the arbiter.
    event DisputeRaised(uint256 indexed id, address indexed by);

    /// @notice Emitted when an address withdraws its accumulated balance.
    event Withdrawn(address indexed who, uint256 amount);

    /// @param _arbiter the address allowed to resolve disputes
    constructor(address _arbiter) {
        require(_arbiter != address(0), "arbiter is zero address");
        arbiter = _arbiter;
    }

    /// @notice Buyer creates an escrow and locks the funds in a single call.
    ///         The locked amount is whatever ETH is sent with the call.
    ///         The escrow starts directly in Funded; the seller joins later.
    /// @return id the identifier of the new escrow (to share with the seller)
    function createEscrow() external payable returns (uint256 id) {
        require(msg.value > 0, "amount must be positive");
        require(msg.sender != arbiter, "arbiter cannot be a party");

        id = nextId;
        transactions[id] = Transaction({
            buyer: msg.sender,
            seller: address(0),
            amount: msg.value,
            state: State.Funded,
            shipDeadline: block.timestamp + SHIP_TIMEOUT,
            confirmDeadline: 0
        });
        nextId++;

        emit EscrowCreated(id, msg.sender, msg.value);
    }

    /// @notice Seller joins a funded escrow via the shared link, becoming the
    ///         counterparty. The first valid caller takes the seller slot.
    /// @param _id the escrow to join
    function joinEscrow(uint256 _id) external {
        require(_id < nextId, "escrow does not exist");

        Transaction storage t = transactions[_id];
        require(t.state == State.Funded, "escrow not joinable");
        require(t.seller == address(0), "seller already joined");
        require(msg.sender != t.buyer, "buyer cannot be seller");
        require(msg.sender != arbiter, "arbiter cannot be a party");

        t.seller = msg.sender;

        emit SellerJoined(_id, msg.sender);
    }

    /// @notice Buyer cancels and reclaims the funds while no seller has joined,
    ///         moving Funded -> Refunded without waiting for the ship timeout.
    /// @param _id the escrow to cancel
    function cancelEscrow(uint256 _id) external {
        require(_id < nextId, "escrow does not exist");

        Transaction storage t = transactions[_id];
        require(msg.sender == t.buyer, "only buyer can cancel");
        require(t.state == State.Funded, "escrow not in Funded state");
        require(t.seller == address(0), "seller already joined");

        t.state = State.Refunded;
        pendingWithdrawals[t.buyer] += t.amount;

        emit EscrowRefunded(_id);
    }

    /// @notice Seller marks the item as shipped, moving Funded -> Shipped and
    ///         starting the buyer's confirmation timeout.
    /// @param _id the escrow being shipped
    function markShipped(uint256 _id) external {
        require(_id < nextId, "escrow does not exist");

        Transaction storage t = transactions[_id];
        require(msg.sender == t.seller, "only seller can ship");
        require(t.state == State.Funded, "escrow not in Funded state");

        t.state = State.Shipped;
        t.confirmDeadline = block.timestamp + CONFIRM_TIMEOUT;

        emit ItemShipped(_id, t.confirmDeadline);
    }

    /// @notice Buyer confirms receipt, moving Shipped -> Completed and crediting
    ///         the sale amount to the seller for withdrawal.
    /// @param _id the escrow being confirmed
    function confirmReceipt(uint256 _id) external {
        require(_id < nextId, "escrow does not exist");

        Transaction storage t = transactions[_id];
        require(msg.sender == t.buyer, "only buyer can confirm");
        require(t.state == State.Shipped, "escrow not in Shipped state");

        t.state = State.Completed;
        pendingWithdrawals[t.seller] += t.amount;

        emit EscrowCompleted(_id);
    }

    /// @notice Buyer reclaims the funds if the seller never shipped in time,
    ///         moving Funded -> Refunded and crediting the amount back to the
    ///         buyer for withdrawal. Protects the buyer from inaction.
    /// @param _id the escrow to refund
    function refundExpired(uint256 _id) external {
        require(_id < nextId, "escrow does not exist");

        Transaction storage t = transactions[_id];
        require(msg.sender == t.buyer, "only buyer can claim refund");
        require(t.state == State.Funded, "escrow not in Funded state");
        require(block.timestamp >= t.shipDeadline, "ship deadline not reached");

        t.state = State.Refunded;
        pendingWithdrawals[t.buyer] += t.amount;

        emit EscrowRefunded(_id);
    }

    /// @notice Seller forces completion if the buyer never confirmed in time,
    ///         moving Shipped -> Completed and crediting the sale amount to the
    ///         seller for withdrawal. Protects the seller from inaction.
    /// @param _id the escrow to auto-complete
    function autoComplete(uint256 _id) external {
        require(_id < nextId, "escrow does not exist");

        Transaction storage t = transactions[_id];
        require(msg.sender == t.seller, "only seller can auto-complete");
        require(t.state == State.Shipped, "escrow not in Shipped state");
        require(block.timestamp >= t.confirmDeadline, "confirm deadline not reached");

        t.state = State.Completed;
        pendingWithdrawals[t.seller] += t.amount;

        emit EscrowCompleted(_id);
    }

    /// @notice Either party escalates a shipped deal to the arbiter,
    ///         moving Shipped -> Disputed. A dispute can start only here.
    /// @param _id the escrow to dispute
    function raiseDispute(uint256 _id) external {
        require(_id < nextId, "escrow does not exist");

        Transaction storage t = transactions[_id];
        require(msg.sender == t.buyer || msg.sender == t.seller, "only parties can dispute");
        require(t.state == State.Shipped, "dispute only from Shipped");

        t.state = State.Disputed;

        emit DisputeRaised(_id, msg.sender);
    }

    /// @notice Arbiter rules in favor of the seller, moving Disputed -> Completed
    ///         and crediting the sale amount to the seller for withdrawal.
    /// @param _id the disputed escrow
    function resolveForSeller(uint256 _id) external {
        require(_id < nextId, "escrow does not exist");

        Transaction storage t = transactions[_id];
        require(msg.sender == arbiter, "only arbiter can resolve");
        require(t.state == State.Disputed, "escrow not disputed");

        t.state = State.Completed;
        pendingWithdrawals[t.seller] += t.amount;

        emit EscrowCompleted(_id);
    }

    /// @notice Arbiter rules in favor of the buyer, moving Disputed -> Refunded
    ///         and crediting the amount back to the buyer for withdrawal.
    /// @param _id the disputed escrow
    function resolveForBuyer(uint256 _id) external {
        require(_id < nextId, "escrow does not exist");

        Transaction storage t = transactions[_id];
        require(msg.sender == arbiter, "only arbiter can resolve");
        require(t.state == State.Disputed, "escrow not disputed");

        t.state = State.Refunded;
        pendingWithdrawals[t.buyer] += t.amount;

        emit EscrowRefunded(_id);
    }

    /// @notice Withdraw the caller's entire accumulated balance.
    /// @dev Checks-effects-interactions: the balance is zeroed BEFORE the
    ///      external call, so a malicious recipient cannot re-enter and drain
    ///      more than it is owed.
    function withdraw() external nonReentrant {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "nothing to withdraw");

        pendingWithdrawals[msg.sender] = 0;

        (bool ok, ) = msg.sender.call{value: amount}("");
        require(ok, "transfer failed");

        emit Withdrawn(msg.sender, amount);
    }
}
