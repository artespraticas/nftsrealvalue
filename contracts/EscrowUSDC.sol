// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

contract EscrowUSDC {
    address public sender;
    address public receiver;
    address public usdc;

    uint256 public amount;
    uint256 public deadline;

    bool public senderApproved;
    bool public receiverApproved;
    bool public deposited;

    constructor(
        address _receiver,
        address _usdc,
        uint256 _amount,
        uint256 _durationSeconds
    ) {
        sender = msg.sender;
        receiver = _receiver;
        usdc = _usdc;
        amount = _amount;
        deadline = block.timestamp + _durationSeconds;
    }

    function deposit() external {
        require(msg.sender == sender, "Only sender");
        require(!deposited, "Already deposited");

        IERC20(usdc).transferFrom(sender, address(this), amount);
        deposited = true;
    }

    function approve() external {
        require(deposited, "Not deposited yet");

        if (msg.sender == sender) senderApproved = true;
        if (msg.sender == receiver) receiverApproved = true;

        if (senderApproved && receiverApproved) {
            IERC20(usdc).transfer(receiver, amount);
        }
    }

    function refund() external {
        require(block.timestamp > deadline, "Too early");
        require(deposited, "No funds");

        IERC20(usdc).transfer(sender, amount);
    }
}
