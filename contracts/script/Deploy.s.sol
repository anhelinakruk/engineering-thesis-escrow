// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Escrow} from "../src/Escrow.sol";

/// Deploys Escrow with the arbiter taken from ARBITER_ADDRESS.
/// The deployer key is never read here; pass it to forge (e.g. --account).
contract Deploy is Script {
    function run() external returns (Escrow escrow) {
        address arbiter = vm.envAddress("ARBITER_ADDRESS");

        vm.startBroadcast();
        escrow = new Escrow(arbiter);
        vm.stopBroadcast();

        console.log("Escrow deployed at", address(escrow));
        console.log("Arbiter", arbiter);
    }
}
