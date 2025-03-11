// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../BaseTest.sol";

contract PledgeTest is BaseTest {
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
} 