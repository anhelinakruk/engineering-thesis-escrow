# engineering-thesis-escrow
Decentralized escrow system for peer-to-peer commerce, built on Ethereum smart contracts with a native iOS app.

The contract is deployed on Sepolia at
[`0x9c5776bcF1f1eA263D35a73Eca07112ff132EA12`](https://sepolia.etherscan.io/address/0x9c5776bcF1f1eA263D35a73Eca07112ff132EA12).

## Running locally

### Before a demo

```bash
./start-dev.sh
```

Starts the Podman VM, SurrealDB with the schema from `fixtures/setup.surql`, and the Rust backend on port 3000 (Ctrl+C stops it). Then open `escrow/escrow.xcodeproj` in Xcode and run the app on a simulator.

### One-time setup

Requirements: Xcode, Rust, Foundry, Podman with `podman compose`, and [alloy-swift](https://github.com/anhelinakruk/alloy-swift) cloned to `../visoft/alloy-swift` next to this repository (the Xcode project references it as a local Swift package).

1. `cp .env.example .env` and set `RPC_URL` (Sepolia endpoint), `ESCROW_CONTRACT` and `JWT_SECRET`.
2. `cp escrow/Secrets.example.swift escrow/escrow/Secrets.swift` and put the same Sepolia endpoint in it.

Both files are git-ignored because they hold the RPC key.

### Network

`AppConfig.network` in `escrow/escrow/Config.swift` selects the chain: `.sepolia` (default) or `.anvil` for a local chain with the contract deployed by `contracts/script/Deploy.s.sol`.

## Contract

```bash
cd contracts
forge test              # unit, security and fuzz tests
forge coverage
```

The arbiter settles a dispute with:

```bash
ESCROW_CONTRACT=<address> ESCROW_ID=<id> RULING=buyer \
  forge script script/Resolve.s.sol --rpc-url <rpc> \
  --account <arbiter> --sender <arbiter address> --broadcast
# RULING=seller pays the seller instead
```
