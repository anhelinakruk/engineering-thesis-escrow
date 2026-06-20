# Project: Decentralized Escrow System (engineering thesis)

## Goal
A mobile app that secures payments in peer-to-peer online commerce
using Ethereum smart contracts. Two parties meet outside the app
(e.g. OLX, social media), the buyer creates an escrow, locks the
funds, and shares a link the seller uses to join the transaction.
The app is purely a security layer over a deal that would happen anyway —
it is NOT a marketplace (no listings, no browsing, no search).

## Architecture (3 layers)
- Smart contract: Solidity + Foundry, deployed on the Sepolia testnet
- Backend: Rust + Alloy (NOT ethers-rs)
- Frontend: SwiftUI (iOS), connected to the Rust layer via UniFFI
- Private key: stored in the iOS Keychain

## Design principles
- Funds are held ONLY by the smart contract; no other layer can move them
- All cryptographic logic lives in the Rust layer; Swift is UI only
- No registration or personal data — a user's identity is just their
  Ethereum wallet address
- The arbiter (admin) can only resolve disputes within the contract's
  rules; they cannot seize funds or act outside the defined scenarios

## Transaction state machine
Created → Funded → Shipped → Completed / Disputed / Refunded

Transitions:
- Created → Funded: buyer deposits funds
- Funded → Shipped: seller marks item as shipped
- Funded → Refunded: timeout (seller never shipped)
- Shipped → Completed: buyer confirms receipt
- Shipped → Completed: timeout (buyer never confirmed)
- Shipped → Disputed: either party raises a dispute
- Disputed → Completed: arbiter rules for the seller
- Disputed → Refunded: arbiter rules for the buyer

Two symmetric timeouts protect both sides from the other's inaction.
A dispute can only be raised from the Shipped state.
Completed and Refunded are terminal states.

## Tech stack
- Solidity, Foundry
- Rust, Alloy
- SwiftUI, UniFFI, iOS Keychain
- Sepolia testnet