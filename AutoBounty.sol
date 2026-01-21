// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract AutoBounty is ReentrancyGuard {
    using ECDSA for bytes32;

    IERC20 public immutable usdc;

    uint256 public bountyCount;

    struct Bounty {
        address funder;
        address hunter;
        address verifier;
        uint256 amount;
        uint256 deadline;
        bool paid;
    }

    mapping(uint256 => Bounty) public bounties;

    event BountyPosted(
        uint256 indexed bountyId,
        address indexed funder,
        uint256 amount,
        uint256 deadline,
        address verifier
    );

    event BountyClaimed(
        uint256 indexed bountyId,
        address indexed hunter
    );

    event BountyPaid(
        uint256 indexed bountyId,
        address indexed hunter,
        uint256 amount
    );

    event BountyRefunded(
        uint256 indexed bountyId,
        address indexed funder
    );

    constructor(address _usdc) {
        usdc = IERC20(_usdc);
    }

    // -------------------------
    // POST BOUNTY
    // -------------------------
    function postBounty(
        uint256 amount,
        uint256 deadline,
        address verifier
    ) external nonReentrant {
        require(amount > 0, "Amount = 0");
        require(deadline > block.timestamp, "Invalid deadline");
        require(verifier != address(0), "Verifier = 0");

        bountyCount++;

        bounties[bountyCount] = Bounty({
            funder: msg.sender,
            hunter: address(0),
            verifier: verifier,
            amount: amount,
            deadline: deadline,
            paid: false
        });

        require(
            usdc.transferFrom(msg.sender, address(this), amount),
            "USDC transfer failed"
        );

        emit BountyPosted(bountyCount, msg.sender, amount, deadline, verifier);
    }

    // -------------------------
    // CLAIM BOUNTY (FIRST COME)
    // -------------------------
    function claimBounty(uint256 bountyId) external {
        Bounty storage b = bounties[bountyId];

        require(b.funder != address(0), "Bounty not found");
        require(b.hunter == address(0), "Already claimed");
        require(block.timestamp < b.deadline, "Expired");

        b.hunter = msg.sender;

        emit BountyClaimed(bountyId, msg.sender);
    }

    // -------------------------
    // SUBMIT PROOF & PAYOUT
    // -------------------------
    function submitProof(
        uint256 bountyId,
        bytes calldata signature
    ) external nonReentrant {
        Bounty storage b = bounties[bountyId];

        require(b.hunter == msg.sender, "Not hunter");
        require(!b.paid, "Already paid");
        require(block.timestamp < b.deadline, "Expired");

        bytes32 messageHash = keccak256(
            abi.encodePacked(bountyId, msg.sender, address(this))
        );
        bytes32 message = MessageHashUtils.toEthSignedMessageHash(messageHash);

        address signer = message.recover(signature);
        require(signer == b.verifier, "Invalid proof");

        b.paid = true;

        require(
            usdc.transfer(b.hunter, b.amount),
            "USDC payout failed"
        );

        emit BountyPaid(bountyId, b.hunter, b.amount);
    }

    // -------------------------
    // REFUND AFTER EXPIRY
    // -------------------------
    function refund(uint256 bountyId) external nonReentrant {
        Bounty storage b = bounties[bountyId];

        require(msg.sender == b.funder, "Not funder");
        require(!b.paid, "Already paid");
        require(block.timestamp >= b.deadline, "Not expired");

        b.paid = true;

        require(
            usdc.transfer(b.funder, b.amount),
            "Refund failed"
        );

        emit BountyRefunded(bountyId, b.funder);
    }
}
