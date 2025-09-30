// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {TimeStream} from "../src/TimeStream.sol";
import {MockUSDC} from "../src/MockUSDC.sol";

contract CreateDemo is Script {
    function run() external {
        // .env'den oku
        address employee = vm.envAddress("EMPLOYEE_ADDR");
        address usdcAddr = vm.envAddress("USDC_ADDR");
        address tsAddr = vm.envAddress("TIMESTREAM_ADDR");

        // PK'den adres türet (sender)
        uint256 pk = vm.envUint("EMPLOYER_PK");
        address employer = vm.addr(pk);

        uint40 startTime = uint40(block.timestamp + 60);
        uint40 stopTime = uint40(block.timestamp + 60 + 30 days);
        uint256 deposit = 3_000 * 1e6;

        vm.startBroadcast(pk); // bu pk ile imzala
        MockUSDC(usdcAddr).mint(employer, deposit);
        MockUSDC(usdcAddr).approve(tsAddr, deposit);
        uint256 streamId = TimeStream(tsAddr).createStream(employee, MockUSDC(usdcAddr), deposit, startTime, stopTime);
        vm.stopBroadcast();

        console2.log("Employer:", employer);
        console2.log("Employee:", employee);
        console2.log("StreamID:", streamId);
    }
}
