// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Escrow} from "../src/Escrow.sol";

/// Arbiter's tool: settles a disputed escrow.
/// ESCROW_CONTRACT, ESCROW_ID, and RULING ("seller" or "buyer") come from env;
/// the arbiter's key is passed to forge (e.g. --account), never read here.
/// The contract itself rejects anyone but the arbiter and any non-disputed escrow.
contract Resolve is Script {
    function run() external {
        Escrow escrow = Escrow(vm.envAddress("ESCROW_CONTRACT"));
        uint256 id = vm.envUint("ESCROW_ID");
        bytes32 ruling = keccak256(bytes(vm.envString("RULING")));

        vm.startBroadcast();
        if (ruling == keccak256("seller")) {
            escrow.resolveForSeller(id);
        } else if (ruling == keccak256("buyer")) {
            escrow.resolveForBuyer(id);
        } else {
            revert("RULING must be seller or buyer");
        }
        vm.stopBroadcast();

        console.log("Escrow", id, "resolved for", vm.envString("RULING"));
    }
}
