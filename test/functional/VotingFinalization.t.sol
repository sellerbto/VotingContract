// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../BaseTest.sol";

contract VotingFinalizationTest is BaseTest {
    function testFinalizeVotingByDeadline() public {
        uint256 amount = 1000 * 10**18;
        uint32 stakeDuration = 30 days;
        
        vm.startPrank(user);
        token.approve(address(voteTable), amount);
        voteTable.pledge(votingId, amount, stakeDuration, true);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 7 days + 1);
        
        (,,,,,bool isActiveBefore, VoteTable.VotingResult resultBefore) = voteTable.votings(votingId);
        assertTrue(isActiveBefore, "Voting should be active before finalization");
        assertEq(uint(resultBefore), uint(VoteTable.VotingResult.Pending), "Result should be pending before finalization");
        
        voteTable.finalizeVotingByDeadline(votingId);
        
        (,,,,,bool isActiveAfter, VoteTable.VotingResult resultAfter) = voteTable.votings(votingId);
        assertFalse(isActiveAfter, "Voting should be inactive after finalization");
        assertEq(uint(resultAfter), uint(VoteTable.VotingResult.Passed), "Result should be passed");
    }
    
    function testFinalizeVotingByDeadlineFailed() public {
        uint256 amount = 1000 * 10**18;
        uint32 stakeDuration = 30 days;
        
        vm.startPrank(user);
        token.approve(address(voteTable), amount);
        voteTable.pledge(votingId, amount, stakeDuration, false);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 7 days + 1);
        
        voteTable.finalizeVotingByDeadline(votingId);
        
        (,,,,,bool isActiveAfter, VoteTable.VotingResult resultAfter) = voteTable.votings(votingId);
        assertFalse(isActiveAfter, "Voting should be inactive after finalization");
        assertEq(uint(resultAfter), uint(VoteTable.VotingResult.Failed), "Result should be failed");
    }
    
    function testFinalizeVotingByDeadlineTie() public {
        uint256 amount = 1000 * 10**18;
        uint32 stakeDuration = 30 days;
        
        vm.startPrank(user);
        token.approve(address(voteTable), amount);
        voteTable.pledge(votingId, amount, stakeDuration, true);
        vm.stopPrank();
        
        vm.startPrank(user2);
        token.approve(address(voteTable), amount);
        voteTable.pledge(votingId, amount, stakeDuration, false);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 7 days + 1);
        
        vm.expectRevert("Voting is a tie");
        voteTable.finalizeVotingByDeadline(votingId);
    }
    
    function testFinalizeVotingByDeadlineBeforeDeadline() public {
        vm.expectRevert("Voting deadline not reached");
        voteTable.finalizeVotingByDeadline(votingId);
        
        vm.warp(block.timestamp + 7 days - 1);
        
        vm.expectRevert("Voting deadline not reached");
        voteTable.finalizeVotingByDeadline(votingId);
    }
    
    function testFinalizeVotingByDeadlineInvalidVotingId() public {
        uint256 invalidVotingId = 999;
        
        vm.expectRevert("Invalid voting id");
        voteTable.finalizeVotingByDeadline(invalidVotingId);
    }
    
    function testFinalizeVotingByDeadlineAlreadyFinalized() public {
        uint256 amount = 1000 * 10**18;
        uint32 stakeDuration = 30 days;
        
        vm.startPrank(user);
        token.approve(address(voteTable), amount);
        voteTable.pledge(votingId, amount, stakeDuration, true);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 7 days + 1);
        
        voteTable.finalizeVotingByDeadline(votingId);
        
        vm.expectRevert("Voting already finalized");
        voteTable.finalizeVotingByDeadline(votingId);
    }
    
    function testFinalizeVotingByThreshold() public {
        uint256 lowThreshold = 100 * 10**18;
        voteTable.createVoting("Threshold Test", lowThreshold, 7 days);
        uint256 thresholdVotingId = 1;
        
        uint256 amount = 1000 * 10**18;
        uint32 stakeDuration = 365 days;
        
        (,,,,,bool isActiveBefore,) = voteTable.votings(thresholdVotingId);
        assertTrue(isActiveBefore, "Voting should be active before pledge");
        
        vm.startPrank(user);
        token.approve(address(voteTable), amount);
        voteTable.pledge(thresholdVotingId, amount, stakeDuration, true);
        vm.stopPrank();
        
        (,,,,,bool isActiveAfter, VoteTable.VotingResult resultAfter) = voteTable.votings(thresholdVotingId);
        assertFalse(isActiveAfter, "Voting should be inactive after threshold is reached");
        assertEq(uint(resultAfter), uint(VoteTable.VotingResult.Passed), "Result should be passed");
    }
    
    function testFinalizeVotingByThresholdAgainst() public {
        uint256 lowThreshold = 100 * 10**18;
        voteTable.createVoting("Threshold Against Test", lowThreshold, 7 days);
        uint256 thresholdVotingId = 1;
        
        uint256 amount = 1000 * 10**18;
        uint32 stakeDuration = 365 days;
        
        vm.startPrank(user);
        token.approve(address(voteTable), amount);
        voteTable.pledge(thresholdVotingId, amount, stakeDuration, false);
        vm.stopPrank();
        
        (,,,,,bool isActiveAfter, VoteTable.VotingResult resultAfter) = voteTable.votings(thresholdVotingId);
        assertFalse(isActiveAfter, "Voting should be inactive after threshold is reached");
        assertEq(uint(resultAfter), uint(VoteTable.VotingResult.Failed), "Result should be failed");
    }
} 