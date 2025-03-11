// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../BaseTest.sol";

contract VotingCreationTest is BaseTest {
    function testCreateVoting() public {
        VoteTable newVoteTable = new VoteTable(address(token));
        vm.startPrank(admin);
        newVoteTable.grantRole(newVoteTable.ADMIN_ROLE(), admin);
        
        string memory description = "Test Voting";
        uint256 votingThreshold = 1000;
        uint32 votingDuration = 1 days;
        
        newVoteTable.createVoting(description, votingThreshold, votingDuration);
        
        (
            string memory storedDescription,
            uint256 powerVotedFor,
            uint256 powerVotedAgainst,
            uint256 storedVotingThreshold,
            uint32 endTime,
            bool isActive,
            VoteTable.VotingResult result
        ) = newVoteTable.votings(0);
        
        assertEq(storedDescription, description, "Description should match");
        assertEq(powerVotedFor, 0, "Initial power voted for should be 0");
        assertEq(powerVotedAgainst, 0, "Initial power voted against should be 0");
        assertEq(storedVotingThreshold, votingThreshold, "Voting threshold should match");
        assertEq(endTime, block.timestamp + votingDuration, "End time should be correctly set");
        assertTrue(isActive, "Voting should be active");
        assertEq(uint(result), uint(VoteTable.VotingResult.Pending), "Result should be pending");
        
        assertEq(newVoteTable.votingCount(), 1, "Voting count should be incremented");
        vm.stopPrank();
    }
    
    function testCreateVotingWithZeroDuration() public {
        string memory description = "Test Voting";
        uint256 votingThreshold = 1000;
        uint32 votingDuration = 0;
        
        vm.expectRevert("End time must be in the future");
        voteTable.createVoting(description, votingThreshold, votingDuration);
    }
    
    function testCreateVotingWithZeroThreshold() public {
        string memory description = "Test Voting";
        uint256 votingThreshold = 0;
        uint32 votingDuration = 1 days;
        
        vm.expectRevert("Voting threshold must be greater than 0");
        voteTable.createVoting(description, votingThreshold, votingDuration);
    }
    
    function testCreateVotingWithEmptyDescription() public {
        string memory description = "";
        uint256 votingThreshold = 1000;
        uint32 votingDuration = 1 days;
        
        vm.expectRevert("Description must be non-empty");
        voteTable.createVoting(description, votingThreshold, votingDuration);
    }
    
    function testCreateVotingNonAdmin() public {
        string memory description = "Test Voting";
        uint256 votingThreshold = 1000;
        uint32 votingDuration = 1 days;
        
        vm.startPrank(user);
        
        vm.expectRevert();
        voteTable.createVoting(description, votingThreshold, votingDuration);
        
        vm.stopPrank();
    }
    
    function testCreateVotingWithLongDescription() public {
        string memory longDescription = string(new bytes(500));
        
        vm.expectRevert();
        voteTable.createVoting(longDescription, 100, 1 days);
    }
    
    function testCreateVotingSequentialIds() public {
        VoteTable newVoteTable = new VoteTable(address(token));
        vm.startPrank(admin);
        newVoteTable.grantRole(newVoteTable.ADMIN_ROLE(), admin);
        
        newVoteTable.createVoting("First Voting", 1000, 1 days);
        newVoteTable.createVoting("Second Voting", 2000, 2 days);
        newVoteTable.createVoting("Third Voting", 3000, 3 days);
        
        assertEq(newVoteTable.votingCount(), 3, "Voting count should be 3");
        
        (string memory desc1,,,,,,) = newVoteTable.votings(0);
        (string memory desc2,,,,,,) = newVoteTable.votings(1);
        (string memory desc3,,,,,,) = newVoteTable.votings(2);
        
        assertEq(desc1, "First Voting", "First voting description should match");
        assertEq(desc2, "Second Voting", "Second voting description should match");
        assertEq(desc3, "Third Voting", "Third voting description should match");
        vm.stopPrank();
    }
} 