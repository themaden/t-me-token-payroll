// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {TimeStream} from "../src/TimeStream.sol";
import {MockUSDC} from "../src/MockUSDC.sol";

contract TimeStreamTest is Test {
    TimeStream ts;
    MockUSDC usdc;
    address employer = address(0xE1);
    address employee = address(0xE2);

    function setUp() public {
        ts = new TimeStream();
        usdc = new MockUSDC();
    }

    function test_StreamAndWithdraw() public {
        uint40 startTime = uint40(block.timestamp + 1);
        uint40 stopTime  = uint40(block.timestamp + 1 + 10 days);
        uint256 deposit  = 1_000 * 1e6; // 1000 mUSDC

        // employer'a mint
        usdc.mint(employer, deposit);

        // employer ile onay ve stream
        vm.startPrank(employer);
        usdc.approve(address(ts), deposit);
        uint256 id = ts.createStream(employee, usdc, deposit, startTime, stopTime);
        vm.stopPrank();

        // başlama anını geç
        vm.warp(startTime + 300); // 5 dakika ilerlet

        // employee çekim yapsın
        vm.startPrank(employee);
        (, uint256 withdrawableBefore) = ts.balanceOf(id);
        assertGt(withdrawableBefore, 0);
        ts.withdraw(id, withdrawableBefore / 2);
        vm.stopPrank();

        // kalan çekilebilir azalmış olmalı
        (, uint256 withdrawableAfter) = ts.balanceOf(id);
        assertLt(withdrawableAfter, withdrawableBefore);
    }
}
