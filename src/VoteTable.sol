// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract VoteTable is AccessControl, ERC721URIStorage, IERC721Receiver {
    using SafeERC20 for IERC20;

    enum VotingResult {
        Pending,
        Passed,
        Failed
    }

    struct Voting {
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

    // Events
    event VotingCreated(
        uint256 indexed votingId,
        string description,
        uint256 votingThreshold,
        uint32 endTime,
        address indexed creator
    );

    event VotingFinalized(
        uint256 indexed votingId,
        uint256 powerVotedFor,
        uint256 powerVotedAgainst,
        VotingResult result
    );

    event VoteCast(
        uint256 indexed votingId,
        uint256 indexed voteId,
        address indexed voter,
        uint256 stakedAmount,
        uint256 votingPower,
        bool isFor,
        uint32 stakeEndTime
    );

    event VoteUnpledged(
        uint256 indexed votingId,
        uint256 indexed voteId,
        address indexed voter,
        uint256 returnedAmount
    );

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    uint256 public votingCount;
    uint256 public voteCount;
    IERC20 public immutable token;

    mapping(uint256 => Voting) public votings;
    mapping(uint256 => mapping(address => mapping(uint256 => Vote)))
        public votes;

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
        require(bytes(description).length < 500, "Description must be less than 500 characters");

        // Does i need to check votingThreshold is less than some value or it is an admin fault if he sets it to max value?

        uint32 endTime = uint32(block.timestamp + votingDuration);
        
        votings[votingCount] = Voting({
            description: description,
            powerVotedFor: 0,
            powerVotedAgainst: 0,
            endTime: endTime,
            votingThreshold: votingThreshold,
            isActive: true,
            result: VotingResult.Pending
        });
        
        emit VotingCreated(
            votingCount,
            description,
            votingThreshold,
            endTime,
            msg.sender
        );
        
        votingCount++;
    }

    function finalizeVotingByDeadline(
        uint256 votingId
    ) public onlyRole(ADMIN_ROLE) {
        require(votingId < votingCount, "Invalid voting id");
        Voting storage voting = votings[votingId];
        require(voting.isActive, "Voting already finalized");
        require(
            block.timestamp >= voting.endTime,
            "Voting deadline not reached"
        );
        require(
            voting.powerVotedFor != voting.powerVotedAgainst,
            "Voting is a tie"
        );

        voting.isActive = false;

        if (voting.powerVotedFor > voting.powerVotedAgainst) {
            voting.result = VotingResult.Passed;
        } else {
            voting.result = VotingResult.Failed;
        }

        emit VotingFinalized(
            votingId,
            voting.powerVotedFor,
            voting.powerVotedAgainst,
            voting.result
        );

        _mintResultNFT(votingId);
    }

    function pledge(
        uint256 votingId,
        uint256 amount,
        uint32 stakeDuration,
        bool isFor
    ) external {
        require(votingId < votingCount, "Invalid voting id");
        require(amount > 0, "Amount must be greater than 0");
        require(stakeDuration > 0, "Stake duration must be greater than 0");
        require(
            stakeDuration <= 365 days * 4,
            "Stake duration must be less than 4 years"
        );

        Voting storage voting = votings[votingId];
        require(voting.isActive, "Voting is not active");
        require(voting.endTime >= block.timestamp, "Voting has ended");

        require(
            token.balanceOf(msg.sender) >= amount,
            "Insufficient token balance"
        );
        require(
            token.allowance(msg.sender, address(this)) >= amount,
            "Insufficient token allowance"
        );

        token.safeTransferFrom(msg.sender, address(this), amount);
        uint256 votingPower = _getVotingPower(amount, stakeDuration);

        if (isFor) {
            voting.powerVotedFor += votingPower;
        } else {
            voting.powerVotedAgainst += votingPower;
        }

        uint32 stakeEndTime = uint32(block.timestamp + stakeDuration);
        
        votes[votingId][msg.sender][voteCount] = Vote({
            stakedAmount: amount,
            votingPower: votingPower,
            isFor: isFor,
            stakeEndTime: stakeEndTime,
            isValue: true
        });

        emit VoteCast(
            votingId,
            voteCount,
            msg.sender,
            amount,
            votingPower,
            isFor,
            stakeEndTime
        );

        voteCount++;

        _checkAndFinalizeByThreshold(votingId);
    }

    function unpledge(uint256 votingId, uint voteId) external {
        require(votingId < votingCount, "Invalid voting id");
        Vote storage vote = votes[votingId][msg.sender][voteId];
        require(vote.isValue, "Vote does not exist");
        require(block.timestamp >= vote.stakeEndTime, "Stake is not over");

        uint256 amountToReturn = vote.stakedAmount;

        Voting storage voting = votings[votingId];
        if (voting.isActive) {
            if (vote.isFor) {
                voting.powerVotedFor -= vote.votingPower;
            } else {
                voting.powerVotedAgainst -= vote.votingPower;
            }
        }

        vote.stakedAmount = 0;
        vote.votingPower = 0;

        emit VoteUnpledged(
            votingId,
            voteId,
            msg.sender,
            amountToReturn
        );

        token.safeTransfer(msg.sender, amountToReturn);
    }

    function _checkAndFinalizeByThreshold(uint256 votingId) internal {
        Voting storage voting = votings[votingId];
        if (!voting.isActive) return;

        if (voting.powerVotedFor >= voting.votingThreshold) {
            voting.isActive = false;
            voting.result = VotingResult.Passed;
            
            emit VotingFinalized(
                votingId,
                voting.powerVotedFor,
                voting.powerVotedAgainst,
                voting.result
            );
            
            _mintResultNFT(votingId);
        } else if (voting.powerVotedAgainst >= voting.votingThreshold) {
            voting.isActive = false;
            voting.result = VotingResult.Failed;
            
            emit VotingFinalized(
                votingId,
                voting.powerVotedFor,
                voting.powerVotedAgainst,
                voting.result
            );
            
            _mintResultNFT(votingId);
        }
    }

    function _mintResultNFT(uint256 votingId) internal {
        Voting storage voting = votings[votingId];

        _safeMint(address(this), votingId);

        string memory metadata = string(
            abi.encodePacked(
                '{"description":"',
                voting.description,
                '","votedFor":',
                Strings.toString(voting.powerVotedFor),
                ',"votedAgainst":',
                Strings.toString(voting.powerVotedAgainst),
                ',"result":"',
                voting.result == VotingResult.Passed ? "Passed" : "Failed",
                '"}'
            )
        );

        _setTokenURI(votingId, metadata);
    }

    function _getVotingPower(
        uint256 stakeAmount,
        uint32 stakeDuration
    ) internal pure returns (uint256) {
        require(
            stakeDuration <= 365 days * 4,
            "Stake period must not be greater than 4 years"
        );
        return stakeAmount * stakeDuration * stakeDuration;
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721URIStorage, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
