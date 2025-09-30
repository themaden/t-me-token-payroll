// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {TimeStream} from "../src/TimeStream.sol";
import {MockUSDC} from "../src/MockUSDC.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast(); // ANVIL default: Account #0 (employer)
        MockUSDC usdc = new MockUSDC();
        TimeStream ts = new TimeStream();
        vm.stopBroadcast();

        console2.log("MockUSDC:", address(usdc));
        console2.log("TimeStream:", address(ts));
    }
}
