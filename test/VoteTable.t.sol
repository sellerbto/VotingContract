// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {VoteTable} from "../src/VoteTable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 token for testing
contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {
        _mint(msg.sender, 1000000 * 10**18);
    }
}

contract VoteTableTest is Test {
    VoteTable public voteTable;
    MockToken public token;
    address public admin;
    address public user;

    function setUp() public {
        admin = address(this);
        user = address(0x1);
        
        // Deploy mock token
        token = new MockToken();
        
        // Deploy VoteTable contract with the test contract as the admin
        vm.startPrank(admin);
        voteTable = new VoteTable(address(token));
        
        // The contract constructor grants DEFAULT_ADMIN_ROLE to msg.sender (admin)
        // Now we need to grant ADMIN_ROLE to admin
        voteTable.grantRole(voteTable.ADMIN_ROLE(), admin);
        vm.stopPrank();
        
        // Transfer some tokens to the user for testing
        token.transfer(user, 100000 * 10**18);
    }

    function testCreateVoting() public {
        string memory description = "Test Voting";
        uint256 votingThreshold = 1000;
        uint32 votingDuration = 1 days;
        
        // Create a voting
        voteTable.createVoting(description, votingThreshold, votingDuration);
        
        // Get the created voting
        (
            string memory storedDescription,
            uint256 powerVotedFor,
            uint256 powerVotedAgainst,
            uint256 storedVotingThreshold,
            uint32 endTime,
            bool isActive,
            VoteTable.VotingResult result
        ) = voteTable.votings(0);
        
        // Verify the voting was created correctly
        assertEq(storedDescription, description, "Description should match");
        assertEq(powerVotedFor, 0, "Initial power voted for should be 0");
        assertEq(powerVotedAgainst, 0, "Initial power voted against should be 0");
        assertEq(storedVotingThreshold, votingThreshold, "Voting threshold should match");
        assertEq(endTime, block.timestamp + votingDuration, "End time should be correctly set");
        assertTrue(isActive, "Voting should be active");
        assertEq(uint(result), uint(VoteTable.VotingResult.Pending), "Result should be pending");
        
        // Verify voting count was incremented
        assertEq(voteTable.votingCount(), 1, "Voting count should be incremented");
    }
    
    function testCreateVotingWithZeroDuration() public {
        string memory description = "Test Voting";
        uint256 votingThreshold = 1000;
        uint32 votingDuration = 0;
        
        // Expect revert when creating a voting with zero duration
        vm.expectRevert("End time must be in the future");
        voteTable.createVoting(description, votingThreshold, votingDuration);
    }
    
    function testCreateVotingWithZeroThreshold() public {
        string memory description = "Test Voting";
        uint256 votingThreshold = 0;
        uint32 votingDuration = 1 days;
        
        // Expect revert when creating a voting with zero threshold
        vm.expectRevert("Voting threshold must be greater than 0");
        voteTable.createVoting(description, votingThreshold, votingDuration);
    }
    
    function testCreateVotingWithEmptyDescription() public {
        string memory description = "";
        uint256 votingThreshold = 1000;
        uint32 votingDuration = 1 days;
        
        // Expect revert when creating a voting with empty description
        vm.expectRevert("Description must be non-empty");
        voteTable.createVoting(description, votingThreshold, votingDuration);
    }
    
    function testCreateVotingNonAdmin() public {
        string memory description = "Test Voting";
        uint256 votingThreshold = 1000;
        uint32 votingDuration = 1 days;
        
        // Switch to non-admin user
        vm.startPrank(user);
        
        // Expect revert when non-admin tries to create a voting
        vm.expectRevert();
        voteTable.createVoting(description, votingThreshold, votingDuration);
        
        vm.stopPrank();
    }
    
    function testCreateMultipleVotings() public {
        // Create first voting
        voteTable.createVoting("First Voting", 1000, 1 days);
        assertEq(voteTable.votingCount(), 1, "Voting count should be 1");
        
        // Create second voting
        voteTable.createVoting("Second Voting", 2000, 2 days);
        assertEq(voteTable.votingCount(), 2, "Voting count should be 2");
        
        // Verify both votings exist with correct data
        (string memory desc1,,,,,,) = voteTable.votings(0);
        (string memory desc2,,,,,,) = voteTable.votings(1);
        
        assertEq(desc1, "First Voting", "First voting description should match");
        assertEq(desc2, "Second Voting", "Second voting description should match");
    }

    function testCreateVotingWithLongDescription() public {
        string memory longDescription = "This is a very long description for a voting that tests the contract's ability to handle lengthy descriptions. It should work fine as long as the gas limit is not exceeded. We want to make sure that the contract can handle realistic use cases where users might want to provide detailed information about the voting proposal.";
        uint256 votingThreshold = 1000;
        uint32 votingDuration = 1 days;
        
        // Create a voting with a long description
        voteTable.createVoting(longDescription, votingThreshold, votingDuration);
        
        // Get the created voting
        (string memory storedDescription,,,,,, VoteTable.VotingResult result) = voteTable.votings(0);
        
        // Verify the voting was created correctly
        assertEq(storedDescription, longDescription, "Long description should be stored correctly");
        assertEq(uint(result), uint(VoteTable.VotingResult.Pending), "Result should be pending");
    }
    
    function testCreateVotingWithMaxDuration() public {
        string memory description = "Test Voting with Max Duration";
        uint256 votingThreshold = 1000;
        // Use a large but safe duration (10 years)
        uint32 votingDuration = 365 days * 10; 
        
        // Create a voting with a very long duration
        voteTable.createVoting(description, votingThreshold, votingDuration);
        
        // Get the created voting
        (,,,, uint32 endTime,,) = voteTable.votings(0);
        
        // Verify the end time is correctly set
        assertEq(endTime, block.timestamp + votingDuration, "End time should be correctly set to the long duration");
    }
    
    function testCreateVotingWithHighThreshold() public {
        string memory description = "Test Voting with High Threshold";
        uint256 votingThreshold = type(uint256).max; // Maximum possible threshold
        uint32 votingDuration = 1 days;
        
        // Create a voting with maximum threshold
        voteTable.createVoting(description, votingThreshold, votingDuration);
        
        // Get the created voting
        (,,,uint256 storedVotingThreshold,,,) = voteTable.votings(0);
        
        // Verify the threshold is correctly set
        assertEq(storedVotingThreshold, votingThreshold, "High threshold should be stored correctly");
    }
    
    function testCreateVotingSequentialIds() public {
        // Create multiple votings and verify their IDs are sequential
        voteTable.createVoting("First Voting", 1000, 1 days);
        voteTable.createVoting("Second Voting", 2000, 2 days);
        voteTable.createVoting("Third Voting", 3000, 3 days);
        
        // Verify voting count
        assertEq(voteTable.votingCount(), 3, "Voting count should be 3");
        
        // Verify each voting has the correct description
        (string memory desc1,,,,,,) = voteTable.votings(0);
        (string memory desc2,,,,,,) = voteTable.votings(1);
        (string memory desc3,,,,,,) = voteTable.votings(2);
        
        assertEq(desc1, "First Voting", "First voting description should match");
        assertEq(desc2, "Second Voting", "Second voting description should match");
        assertEq(desc3, "Third Voting", "Third voting description should match");
    }
} 