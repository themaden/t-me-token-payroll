// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract TimeStream is ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Stream {
        address employer;
        address employee;
        IERC20 token;
        uint128 ratePerSecond; // saniyede akacak miktar
        uint40 start;
        uint40 stop;
        uint256 withdrawn;     // çalışanca çekilmiş kısım
        bool cancelled;
    }

    uint256 public nextId;
    mapping(uint256 => Stream) public streams;

    event StreamCreated(
        uint256 indexed id,
        address indexed employer,
        address indexed employee,
        address token,
        uint256 deposit,
        uint40 start,
        uint40 stop,
        uint128 ratePerSecond
    );
    event Withdraw(uint256 indexed id, address indexed to, uint256 amount);
    event Cancelled(uint256 indexed id, uint256 paidToEmployee, uint256 refundedToEmployer);

    function createStream(
        address employee,
        IERC20 token,
        uint256 deposit,
        uint40 start,
        uint40 stop
    ) external returns (uint256 id) {
        require(employee != address(0), "zero employee");
        require(stop > start, "bad times");
        require(deposit > 0, "no deposit");

        uint256 duration = uint256(stop - start);
        uint128 rate = uint128(deposit / duration);
        require(rate > 0, "rate=0");

        uint256 required = uint256(rate) * duration; // tamsayı bölme artığını dışarıda bırak
        token.safeTransferFrom(msg.sender, address(this), required);

        id = ++nextId;
        streams[id] = Stream({
            employer: msg.sender,
            employee: employee,
            token: token,
            ratePerSecond: rate,
            start: start,
            stop: stop,
            withdrawn: 0,
            cancelled: false
        });

        emit StreamCreated(id, msg.sender, employee, address(token), required, start, stop, rate);
    }

    function balanceOf(uint256 id) public view returns (uint256 earned, uint256 withdrawable) {
        Stream memory s = streams[id];
        require(s.employee != address(0), "no stream");
        uint40 t = uint40(block.timestamp);

        if (t <= s.start) {
            earned = 0;
        } else if (t >= s.stop) {
            earned = uint256(s.ratePerSecond) * (s.stop - s.start);
        } else {
            earned = uint256(s.ratePerSecond) * (t - s.start);
        }

        if (earned <= s.withdrawn) {
            withdrawable = 0;
        } else {
            withdrawable = earned - s.withdrawn;
        }
    }

    function withdraw(uint256 id, uint256 amount) external nonReentrant {
        Stream storage s = streams[id];
        require(msg.sender == s.employee, "not employee");

        (, uint256 available) = balanceOf(id);
        require(amount > 0 && amount <= available, "bad amount");

        s.withdrawn += amount;
        s.token.safeTransfer(s.employee, amount);
        emit Withdraw(id, s.employee, amount);
    }

    function cancel(uint256 id) external nonReentrant {
        Stream storage s = streams[id];
        require(!s.cancelled, "cancelled");
        require(msg.sender == s.employer || msg.sender == s.employee, "not party");

        (uint256 earned, uint256 available) = balanceOf(id);
        s.cancelled = true;

        // Çalışana hak ettiği kısım
        if (available > 0) {
            s.withdrawn = earned;
            s.token.safeTransfer(s.employee, available);
        }

        // İşverene iade (kalan kısım)
        uint256 total = uint256(s.ratePerSecond) * (s.stop - s.start);
        uint256 paid = earned;
        uint256 refund = total > paid ? total - paid : 0;
        if (refund > 0) {
            s.token.safeTransfer(s.employer, refund);
        }
        emit Cancelled(id, available, refund);
    }
}
