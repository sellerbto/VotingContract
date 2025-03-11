// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../BaseTest.sol";

contract UnpledgeTest is BaseTest {
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
    
    function testUnpledgeAgainstVote() public {
        uint256 amount = 1000 * 10**18;
        uint32 stakeDuration = 30 days;
        bool isFor = false; 
        uint256 voteId = 0;
        
        vm.startPrank(user);
        token.approve(address(voteTable), amount);
        voteTable.pledge(votingId, amount, stakeDuration, isFor);
        
        vm.warp(block.timestamp + stakeDuration + 1);
        
        (,, uint256 powerVotedAgainstBefore,,,,) = voteTable.votings(votingId);
        uint256 expectedVotingPower = amount * stakeDuration * stakeDuration;
        assertEq(powerVotedAgainstBefore, expectedVotingPower, "Initial power voted against should match");
        
        voteTable.unpledge(votingId, voteId);
        
        (,, uint256 powerVotedAgainstAfter,,,,) = voteTable.votings(votingId);
        assertEq(powerVotedAgainstAfter, 0, "Power voted against should be reduced to 0");
        
        (uint256 stakedAmountAfter, uint256 votingPowerAfter, bool isForAfter,,) = voteTable.votes(votingId, user, voteId);
        assertEq(stakedAmountAfter, 0, "Staked amount should be 0 after unpledge");
        assertEq(votingPowerAfter, 0, "Voting power should be 0 after unpledge");
        assertFalse(isForAfter, "Vote direction should be preserved as against");
        
        vm.stopPrank();
    }
    
    function testUnpledgeInvalidVotingId() public {
        uint256 invalidVotingId = 999;
        uint256 voteId = 0;
        
        vm.startPrank(user);
        
        vm.expectRevert("Invalid voting id");
        voteTable.unpledge(invalidVotingId, voteId);
        
        vm.stopPrank();
    }
    
    function testUnpledgeNonExistentVote() public {
        uint256 nonExistentVoteId = 999;
        
        vm.startPrank(user);
        
        vm.expectRevert("Vote does not exist");
        voteTable.unpledge(votingId, nonExistentVoteId);
        
        vm.stopPrank();
    }
    
    function testUnpledgeBeforeStakeEnd() public {
        uint256 amount = 1000 * 10**18;
        uint32 stakeDuration = 30 days;
        bool isFor = true;
        uint256 voteId = 0;
        
        vm.startPrank(user);
        token.approve(address(voteTable), amount);
        voteTable.pledge(votingId, amount, stakeDuration, isFor);
        
        vm.expectRevert("Stake is not over");
        voteTable.unpledge(votingId, voteId);
        
        vm.warp(block.timestamp + stakeDuration - 1);
        
        vm.expectRevert("Stake is not over");
        voteTable.unpledge(votingId, voteId);
        
        vm.stopPrank();
    }
    
    function testUnpledgeInactiveVoting() public {
        uint256 lowThreshold = 100 * 10**18;
        voteTable.createVoting("Inactive Voting Test", lowThreshold, 7 days);
        uint256 inactiveVotingId = 1;
        
        uint256 amount = 1000 * 10**18;
        uint32 stakeDuration = 30 days;
        bool isFor = true;
        uint256 voteId = 0;
        
        vm.startPrank(user);
        token.approve(address(voteTable), amount);
        
        voteTable.pledge(inactiveVotingId, amount, stakeDuration, isFor);
        
        (,,,,,bool isActive,) = voteTable.votings(inactiveVotingId);
        assertFalse(isActive, "Voting should be inactive after threshold is reached");
        
        vm.warp(block.timestamp + stakeDuration + 1);
        
        uint256 balanceBefore = token.balanceOf(user);
        
        voteTable.unpledge(inactiveVotingId, voteId);
        
        uint256 balanceAfter = token.balanceOf(user);
        assertEq(balanceAfter, balanceBefore + amount, "User should receive staked amount back");
        
        (uint256 stakedAmountAfter, uint256 votingPowerAfter,,, bool isValueAfter) = voteTable.votes(inactiveVotingId, user, voteId);
        assertEq(stakedAmountAfter, 0, "Staked amount should be 0 after unpledge");
        assertEq(votingPowerAfter, 0, "Voting power should be 0 after unpledge");
        assertTrue(isValueAfter, "Vote should still be marked as valid");

        uint256 expectedVotingPowerFor = amount * stakeDuration * stakeDuration;
        (,uint256 powerVotedFor, uint256 powerVotedAgainst,,,,) = voteTable.votings(inactiveVotingId);
        assertTrue(powerVotedFor == expectedVotingPowerFor && powerVotedAgainst == 0, "Voting power must not be changed");
        
        vm.stopPrank();
    }
    
    function testUnpledgeMultipleVotes() public {
        uint256 amount1 = 1000 * 10**18;
        uint32 stakeDuration1 = 30 days;
        bool isFor1 = true;
        uint256 voteId1 = 0;
        
        uint256 amount2 = 2000 * 10**18;
        uint32 stakeDuration2 = 60 days;
        bool isFor2 = false;
        uint256 voteId2 = 1;
        
        vm.startPrank(user);
        token.approve(address(voteTable), amount1 + amount2);
        
        voteTable.pledge(votingId, amount1, stakeDuration1, isFor1);
        
        voteTable.pledge(votingId, amount2, stakeDuration2, isFor2);
        
        (,uint256 powerVotedForBefore, uint256 powerVotedAgainstBefore,,,,) = voteTable.votings(votingId);
        uint256 expectedVotingPower1 = amount1 * stakeDuration1 * stakeDuration1;
        uint256 expectedVotingPower2 = amount2 * stakeDuration2 * stakeDuration2;
        assertEq(powerVotedForBefore, expectedVotingPower1, "Initial power voted for should match");
        assertEq(powerVotedAgainstBefore, expectedVotingPower2, "Initial power voted against should match");
        
        vm.warp(block.timestamp + stakeDuration1 + 1);
        
        voteTable.unpledge(votingId, voteId1);
        
        (,uint256 powerVotedForAfter1, uint256 powerVotedAgainstAfter1,,,,) = voteTable.votings(votingId);
        assertEq(powerVotedForAfter1, 0, "Power voted for should be reduced to 0");
        assertEq(powerVotedAgainstAfter1, expectedVotingPower2, "Power voted against should remain unchanged");
        
        vm.warp(block.timestamp + stakeDuration2);
        
        voteTable.unpledge(votingId, voteId2);
        
        (,uint256 powerVotedForAfter2, uint256 powerVotedAgainstAfter2,,,,) = voteTable.votings(votingId);
        assertEq(powerVotedForAfter2, 0, "Power voted for should remain 0");
        assertEq(powerVotedAgainstAfter2, 0, "Power voted against should be reduced to 0");
        
        vm.stopPrank();
    }
    
    function testUnpledgeTwice() public {
        uint256 amount = 1000 * 10**18;
        uint32 stakeDuration = 30 days;
        bool isFor = true;
        uint256 voteId = 0;
        
        vm.startPrank(user);
        token.approve(address(voteTable), amount);
        voteTable.pledge(votingId, amount, stakeDuration, isFor);
        
        vm.warp(block.timestamp + stakeDuration + 1);
        
        voteTable.unpledge(votingId, voteId);
        
        voteTable.unpledge(votingId, voteId);
        
        (uint256 stakedAmountAfter, uint256 votingPowerAfter,,, bool isValueAfter) = voteTable.votes(votingId, user, voteId);
        assertEq(stakedAmountAfter, 0, "Staked amount should still be 0 after second unpledge");
        assertEq(votingPowerAfter, 0, "Voting power should still be 0 after second unpledge");
        assertTrue(isValueAfter, "Vote should still be marked as valid");
        
        vm.stopPrank();
    }
} 