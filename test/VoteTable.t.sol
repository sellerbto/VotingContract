// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {VoteTable} from "../src/VoteTable.sol";
import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";


contract VoteTableTest is Test {
    VoteTable public voteTable;
    ERC20Mock public token;
    address public admin;
    address public user;
    address public user2;
    uint256 public votingId;

    function setUp() public {
        admin = address(this);
        user = address(0x1);
        user2 = address(0x2);
        
        token = new ERC20Mock();
        token.mint(admin, 1000000 * 10**18);
        
        vm.startPrank(admin);
        voteTable = new VoteTable(address(token));
        
        voteTable.grantRole(voteTable.ADMIN_ROLE(), admin);
        vm.stopPrank();
        
        token.transfer(user, 100000 * 10**18);
        token.transfer(user2, 100000 * 10**18);
        
        string memory description = "Test Voting";
        uint256 votingThreshold = 1000 * 10**36;
        uint32 votingDuration = 7 days;
        
        voteTable.createVoting(description, votingThreshold, votingDuration);
        votingId = 0;
    }

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
    
    function testPledgeFor() public {
        uint256 amount = 1000 * 10**18;
        uint32 stakeDuration = 30 days;
        bool isFor = true;
        
        vm.startPrank(user);
        token.approve(address(voteTable), amount);
        
        uint256 initialBalance = token.balanceOf(user);
        uint256 initialContractBalance = token.balanceOf(address(voteTable));
        
        voteTable.pledge(votingId, amount, stakeDuration, isFor);
        
        uint256 finalBalance = token.balanceOf(user);
        uint256 finalContractBalance = token.balanceOf(address(voteTable));
        
        assertEq(finalBalance, initialBalance - amount, "User balance should decrease by pledged amount");
        assertEq(finalContractBalance, initialContractBalance + amount, "Contract balance should increase by pledged amount");
        
        (,uint256 powerVotedFor,uint256 powerVotedAgainst,,,,) = voteTable.votings(votingId);
        uint256 expectedVotingPower = amount * stakeDuration * stakeDuration;
        assertEq(powerVotedFor, expectedVotingPower, "Power voted for should increase by voting power");
        assertEq(powerVotedAgainst, 0, "Power voted against should remain unchanged");
        
        (uint256 stakedAmount, uint256 votingPower, bool voteIsFor, uint32 stakeEndTime, bool isValue) = voteTable.votes(votingId, user, 0);
        assertEq(stakedAmount, amount, "Staked amount should match");
        assertEq(votingPower, expectedVotingPower, "Voting power should match");
        assertTrue(voteIsFor, "Vote should be for");
        assertEq(stakeEndTime, block.timestamp + stakeDuration, "Stake end time should be correct");
        assertTrue(isValue, "Vote should be marked as valid");
        
        assertEq(voteTable.voteCount(), 1, "Vote count should be incremented");
        
        vm.stopPrank();
    }
    
    function testPledgeAgainst() public {
        uint256 amount = 1000 * 10**18;
        uint32 stakeDuration = 30 days;
        bool isFor = false;
        
        vm.startPrank(user);
        token.approve(address(voteTable), amount);
        
        voteTable.pledge(votingId, amount, stakeDuration, isFor);
        
        (,uint256 powerVotedFor,uint256 powerVotedAgainst,,,,) = voteTable.votings(votingId);
        uint256 expectedVotingPower = amount * stakeDuration * stakeDuration;
        assertEq(powerVotedFor, 0, "Power voted for should remain unchanged");
        assertEq(powerVotedAgainst, expectedVotingPower, "Power voted against should increase by voting power");
        
        (uint256 stakedAmount, uint256 votingPower, bool voteIsFor,,) = voteTable.votes(votingId, user, 0);
        assertEq(stakedAmount, amount, "Staked amount should match");
        assertEq(votingPower, expectedVotingPower, "Voting power should match");
        assertFalse(voteIsFor, "Vote should be against");
        
        vm.stopPrank();
    }
    
    function testPledgeInvalidVotingId() public {
        uint256 amount = 1000 * 10**18;
        uint32 stakeDuration = 30 days;
        bool isFor = true;
        uint256 invalidVotingId = 999;
        
        vm.startPrank(user);
        token.approve(address(voteTable), amount);
        
        vm.expectRevert("Invalid voting id");
        voteTable.pledge(invalidVotingId, amount, stakeDuration, isFor);
        
        vm.stopPrank();
    }
    
    function testPledgeZeroAmount() public {
        uint256 amount = 0;
        uint32 stakeDuration = 30 days;
        bool isFor = true;
        
        vm.startPrank(user);
        
        vm.expectRevert("Amount must be greater than 0");
        voteTable.pledge(votingId, amount, stakeDuration, isFor);
        
        vm.stopPrank();
    }
    
    function testPledgeZeroStakeDuration() public {
        uint256 amount = 1000 * 10**18;
        uint32 stakeDuration = 0;
        bool isFor = true;
        
        vm.startPrank(user);
        token.approve(address(voteTable), amount);
        
        vm.expectRevert("Stake duration must be greater than 0");
        voteTable.pledge(votingId, amount, stakeDuration, isFor);
        
        vm.stopPrank();
    }
    
    function testPledgeExcessiveStakeDuration() public {
        uint256 amount = 1000 * 10**18;
        uint32 stakeDuration = 365 days * 4 + 1;
        bool isFor = true;
        
        vm.startPrank(user);
        token.approve(address(voteTable), amount);
        
        vm.expectRevert("Stake duration must be less than 4 years");
        voteTable.pledge(votingId, amount, stakeDuration, isFor);
        
        vm.stopPrank();
    }
    
    function testPledgeToEndedVoting() public {
        uint256 amount = 1000 * 10**18;
        uint32 stakeDuration = 30 days;
        bool isFor = true;
        
        vm.warp(block.timestamp + 8 days);
        
        vm.startPrank(user);
        token.approve(address(voteTable), amount);
        
        vm.expectRevert("Voting has ended");
        voteTable.pledge(votingId, amount, stakeDuration, isFor);
        
        vm.stopPrank();
    }
    
    function testPledgeInsufficientBalance() public {
        address poorUser = address(0x3);
        uint256 amount = 1000 * 10**18;
        uint32 stakeDuration = 30 days;
        bool isFor = true;
        
        vm.startPrank(poorUser);
        token.approve(address(voteTable), amount);
        
        vm.expectRevert("Insufficient token balance");
        voteTable.pledge(votingId, amount, stakeDuration, isFor);
        
        vm.stopPrank();
    }
    
    function testPledgeInsufficientAllowance() public {
        uint256 amount = 1000 * 10**18;
        uint32 stakeDuration = 30 days;
        bool isFor = true;
        
        vm.startPrank(user);
        
        vm.expectRevert("Insufficient token allowance");
        voteTable.pledge(votingId, amount, stakeDuration, isFor);
        
        vm.stopPrank();
    }
    
    function testPledgeTriggersThresholdFinalization() public {
        uint256 lowThreshold = 100 * 10**18;
        voteTable.createVoting("Threshold Test Voting", lowThreshold, 7 days);
        uint256 thresholdVotingId = 1;
        
        uint256 amount = 1000 * 10**18;
        uint32 stakeDuration = 365 days;
        bool isFor = true;
        
        vm.startPrank(user);
        token.approve(address(voteTable), amount);
        
        voteTable.pledge(thresholdVotingId, amount, stakeDuration, isFor);
        
        (,,,,,bool isActive, VoteTable.VotingResult result) = voteTable.votings(thresholdVotingId);
        assertFalse(isActive, "Voting should be inactive after threshold is reached");
        assertEq(uint(result), uint(VoteTable.VotingResult.Passed), "Result should be passed");
        
        vm.stopPrank();
    }
    
    function testMultiplePledges() public {
        uint256 amount1 = 1000 * 10**18;
        uint32 stakeDuration1 = 30 days;
        bool isFor1 = true;
        
        uint256 amount2 = 2000 * 10**18;
        uint32 stakeDuration2 = 60 days;
        bool isFor2 = false;
        
        vm.startPrank(user);
        token.approve(address(voteTable), amount1);
        voteTable.pledge(votingId, amount1, stakeDuration1, isFor1);
        vm.stopPrank();
        
        vm.startPrank(user2);
        token.approve(address(voteTable), amount2);
        voteTable.pledge(votingId, amount2, stakeDuration2, isFor2);
        vm.stopPrank();
        
        (,uint256 powerVotedFor,uint256 powerVotedAgainst,,,,) = voteTable.votings(votingId);
        uint256 expectedVotingPower1 = amount1 * stakeDuration1 * stakeDuration1;
        uint256 expectedVotingPower2 = amount2 * stakeDuration2 * stakeDuration2;
        
        assertEq(powerVotedFor, expectedVotingPower1, "Power voted for should match first pledge");
        assertEq(powerVotedAgainst, expectedVotingPower2, "Power voted against should match second pledge");
        
        assertEq(voteTable.voteCount(), 2, "Vote count should be 2");
    }
    
    function testSameUserMultiplePledges() public {
        uint256 amount1 = 1000 * 10**18;
        uint32 stakeDuration1 = 30 days;
        bool isFor1 = true;
        
        uint256 amount2 = 2000 * 10**18;
        uint32 stakeDuration2 = 60 days;
        bool isFor2 = true;
        
        vm.startPrank(user);
        
        token.approve(address(voteTable), amount1 + amount2);
        voteTable.pledge(votingId, amount1, stakeDuration1, isFor1);
        voteTable.pledge(votingId, amount2, stakeDuration2, isFor2);
        
        (,uint256 powerVotedFor,uint256 powerVotedAgainst,,,,) = voteTable.votings(votingId);
        uint256 expectedVotingPower1 = amount1 * stakeDuration1 * stakeDuration1;
        uint256 expectedVotingPower2 = amount2 * stakeDuration2 * stakeDuration2;
        
        assertEq(powerVotedFor, expectedVotingPower1 + expectedVotingPower2, "Power voted for should be sum of both pledges");
        assertEq(powerVotedAgainst, 0, "Power voted against should be 0");
        
        (uint256 stakedAmount1, uint256 votingPower1, bool voteIsFor1, , ) = voteTable.votes(votingId, user, 0);
        (uint256 stakedAmount2, uint256 votingPower2, bool voteIsFor2, , ) = voteTable.votes(votingId, user, 1);
        
        assertEq(stakedAmount1, amount1, "First staked amount should match");
        assertEq(votingPower1, expectedVotingPower1, "First voting power should match");
        assertTrue(voteIsFor1, "First vote should be for");
        
        assertEq(stakedAmount2, amount2, "Second staked amount should match");
        assertEq(votingPower2, expectedVotingPower2, "Second voting power should match");
        assertTrue(voteIsFor2, "Second vote should be for");
        
        vm.stopPrank();
    }

    function testUnpledge() public {
        uint256 amount = 1000 * 10**18;
        uint32 stakeDuration = 30 days;
        bool isFor = true;
        uint256 voteId = 0;
        
        vm.startPrank(user);
        token.approve(address(voteTable), amount);
        voteTable.pledge(votingId, amount, stakeDuration, isFor);
        
        (uint256 stakedAmountBefore, uint256 votingPowerBefore, bool isForBefore, uint32 stakeEndTimeBefore, bool isValueBefore) = voteTable.votes(votingId, user, voteId);
        
        assertEq(stakedAmountBefore, amount, "Initial staked amount should match");
        assertEq(votingPowerBefore, amount * stakeDuration * stakeDuration, "Initial voting power should match");
        assertTrue(isForBefore, "Vote should be for");
        assertEq(stakeEndTimeBefore, block.timestamp + stakeDuration, "Stake end time should be correct");
        assertTrue(isValueBefore, "Vote should be marked as valid");
        
        vm.warp(block.timestamp + stakeDuration + 1);
        
        uint256 balanceBefore = token.balanceOf(user);
        
        voteTable.unpledge(votingId, voteId);
        
        uint256 balanceAfter = token.balanceOf(user);
        assertEq(balanceAfter, balanceBefore + amount, "User should receive staked amount back");
        
        (,uint256 powerVotedForAfter,,,,,) = voteTable.votings(votingId);
        assertEq(powerVotedForAfter, 0, "Power voted for should be reduced to 0");
        
        (uint256 stakedAmountAfter, uint256 votingPowerAfter, bool isForAfter, uint32 stakeEndTimeAfter, bool isValueAfter) = voteTable.votes(votingId, user, voteId);
        
        assertEq(stakedAmountAfter, 0, "Staked amount should be 0 after unpledge");
        assertEq(votingPowerAfter, 0, "Voting power should be 0 after unpledge");
        assertTrue(isForAfter, "Vote direction should be preserved");
        assertEq(stakeEndTimeAfter, stakeEndTimeBefore, "Stake end time should be preserved");
        assertTrue(isValueAfter, "Vote should still be marked as valid");
        
        vm.stopPrank();
    }
} 