// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract VoteTable is AccessControl {
    using SafeERC20 for IERC20;

    struct VotingResult {
        uint256 votedFor;
        uint256 votedAgainst;
        uint256 totalVotes;
    }

    struct Voting {
        uint256 id;
        string description;
        uint256 votedFor;
        uint256 votedAgainst;
        uint32 startTime;
        uint32 endTime;
        uint256 votingThreshold;
        bool isActive;
    }

    struct Vote {
        uint256 amount;
        bool isFor;
        uint256 stakeEndTime;
    }

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    uint256 public count;
    IERC20 public immutable token;

    mapping(uint256 => Voting) public votings;
    mapping(uint256 => mapping(address => Vote)) public votes;
    mapping(uint256 => mapping(address => uint256)) public pledgedAmount;

    constructor(address _token) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        token = IERC20(_token);
    }

    function createVoting(
        string memory description,
        uint256 votingThreshold,
        uint32 endTime
    ) public onlyRole(ADMIN_ROLE) {
        require(endTime > block.timestamp, "End time must be in the future");
        require(votingThreshold > 0, "Voting threshold must be greater than 0");
        require(bytes(description).length > 0, "Description must be non-empty");

        votings[count] = Voting(
            count,
            description,
            0,
            0,
            uint32(block.timestamp),
            endTime,
            votingThreshold,
            true
        );
        count++;
    }
}
