// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract VoteTable is AccessControl, ERC721URIStorage {
    using SafeERC20 for IERC20;

    enum VotingResult {
        Pending,
        Passed,
        Failed
    }

    struct Voting {
        uint256 id;
        string description;
        uint256 powerVotedFor;
        uint256 powerVotedAgainst;
        uint256 votingThreshold;
        uint32 endTime;
        bool isActive;
        VotingResult result;
    }

    struct Vote {
        uint256 stakedAmount;
        uint256 votingPower;
        bool isFor;
        uint32 stakeEndTime;
        bool isValue;
    }

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    uint256 public votingCount;
    uint256 public voteCount;
    IERC20 public immutable token;

    mapping(uint256 => Voting) public votings;
    mapping(uint256 => mapping(address => mapping(uint256 => Vote))) public votes;

    constructor(address _token) ERC721("VotingResult", "VOTE") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        token = IERC20(_token);
    }

    function createVoting(
        string memory description,
        uint256 votingThreshold,
        uint32 votingDuration
    ) public onlyRole(ADMIN_ROLE) {
        require(votingDuration > 0, "End time must be in the future");
        require(votingThreshold > 0, "Voting threshold must be greater than 0");
        require(bytes(description).length > 0, "Description must be non-empty");

        votings[votingCount] = Voting({
            id: votingCount,
            description: description,
            powerVotedFor: 0,
            powerVotedAgainst: 0,
            endTime: uint32(block.timestamp + votingDuration),
            votingThreshold: votingThreshold,
            isActive: true,
            result: VotingResult.Pending
        });
        votingCount++;
    }

    function finalizeVotingByDeadline(uint256 votingId) public onlyRole(ADMIN_ROLE) {
        require(votingId < votingCount, "Invalid voting id");
        Voting storage voting = votings[votingId];
        require(voting.isActive, "Voting already finalized");
        require(block.timestamp >= voting.endTime, "Voting deadline not reached");
        require(voting.powerVotedFor != voting.powerVotedAgainst, "Voting is a tie");
        
        voting.isActive = false;
        
        if (voting.powerVotedFor > voting.powerVotedAgainst) {
            voting.result = VotingResult.Passed;
        } else {
            voting.result = VotingResult.Failed;
        }

        
        _mintResultNFT(votingId);
    }

     function _mintResultNFT(uint256 votingId) internal {
        Voting storage voting = votings[votingId];
        
        _safeMint(address(this), votingId);
        
        string memory metadata = string(abi.encodePacked(
            '{"description":"', voting.description,
            '","votedFor":', Strings.toString(voting.powerVotedFor),
            ',"votedAgainst":', Strings.toString(voting.powerVotedAgainst),
            ',"result":"', voting.result == VotingResult.Passed ? "Passed" : "Failed",
            '"}'
        ));
        
        _setTokenURI(votingId, metadata);
    }

    function pledge(uint256 votingId, uint256 amount, uint32 stakeDuration, bool isFor) external {
    require(votingId < votingCount, "Invalid voting id");
    require(token.balanceOf(msg.sender) >= amount, "Insufficient token balance");
    require(token.allowance(msg.sender, address(this)) >= amount, "Insufficient token allowance");
    require(stakeDuration > 0, "Stake duration must be greater than 0");
    require(block.timestamp + stakeDuration <= block.timestamp + 365 days * 4, "Stake duration must be less than 4 years");

    Voting storage voting = votings[votingId];
    require(voting.isActive, "Voting is not active");
    require(voting.endTime >= block.timestamp, "Voting has ended");

    uint256 votingPower = getVotingPower(amount, stakeDuration);
    
    if (isFor) {
        voting.powerVotedFor += votingPower;
    } else {
        voting.powerVotedAgainst += votingPower;
    }
    
    _checkAndFinalizeByThreshold(votingId);
    
    votes[votingId][msg.sender][voteCount] = Vote({
        stakedAmount: amount,
        votingPower: votingPower,
        isFor: isFor,
        stakeEndTime: uint32(block.timestamp + stakeDuration),
        isValue: true
    });

    voteCount++;
    token.safeTransferFrom(msg.sender, address(this), amount);
    }

    function _checkAndFinalizeByThreshold(uint256 votingId) internal {
        Voting storage voting = votings[votingId];
        if (!voting.isActive) return;

        if (voting.powerVotedFor >= voting.votingThreshold) {
            voting.isActive = false;
            voting.result = VotingResult.Passed;
            _mintResultNFT(votingId);
        } else if (voting.powerVotedAgainst >= voting.votingThreshold) {
            voting.isActive = false;
            voting.result = VotingResult.Failed;
            _mintResultNFT(votingId);
        }
    }

    function unpledge(uint256 votingId, uint voteId) external {
        require(votingId < votingCount, "Invalid voting id");
        
        Vote storage vote = votes[votingId][msg.sender][voteId];
        require(vote.isValue, "Vote does not exist");
        require(block.timestamp >= vote.stakeEndTime, "Stake is not over");

        Voting storage voting = votings[votingId];

        if (vote.isFor && voting.isActive) {
            voting.powerVotedFor -= vote.votingPower;
        } else {
            voting.powerVotedAgainst -= vote.votingPower;
        }

        token.safeTransfer(msg.sender, vote.stakedAmount);

        delete votes[votingId][msg.sender][voteId];
    }


    function getVotingPower(uint256 stakeAmount, uint32 stakeDuration) public pure returns (uint256) {
        require(stakeDuration <= 365 days * 4, "Stake period must not be greater than 4 years");
        return stakeAmount * stakeDuration ** 2;
    }


    function _burn(uint256 tokenId) internal override {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721URIStorage, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
