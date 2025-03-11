// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../BaseTest.sol";

contract NFTMintingTest is BaseTest {
    function testNFTMintingOnFinalizeByDeadline() public {
        uint256 currentVotingCount = voteTable.votingCount();
        
        string memory description = "NFT Test Voting";
        uint256 votingThreshold = 1000 * 10**36; 
        uint32 votingDuration = 7 days;
        
        voteTable.createVoting(description, votingThreshold, votingDuration);
        uint256 newVotingId = currentVotingCount;
        
        vm.startPrank(user);
        token.approve(address(voteTable), 1000 * 10**18);
        voteTable.pledge(newVotingId, 1000 * 10**18, 30 days, true);
        vm.stopPrank();
        
        vm.warp(block.timestamp + votingDuration + 1);
        
        (,,,,,bool isActive,) = voteTable.votings(newVotingId);
        assertTrue(isActive, "Voting should be active before finalizing");
        
        voteTable.finalizeVotingByDeadline(newVotingId);
        
        assertEq(voteTable.ownerOf(newVotingId), address(voteTable), "NFT should be owned by the contract");
        
        string memory tokenURI = voteTable.tokenURI(newVotingId);
        
        assertTrue(
            bytes(tokenURI).length > 0,
            "Token URI should not be empty"
        );
        
        assertTrue(
            contains(tokenURI, description),
            "Token URI should contain the voting description"
        );
        
        assertTrue(
            contains(tokenURI, "Passed"),
            "Token URI should contain the voting result (Passed)"
        );
        
        uint256 expectedVotingPower = 1000 * 10**18 * 30 days * 30 days;
        assertTrue(
            contains(tokenURI, vm.toString(expectedVotingPower)),
            "Token URI should contain the correct voting power"
        );
    }
    
    function testNFTMintingOnFinalizeByThreshold() public {
        uint256 currentVotingCount = voteTable.votingCount();
        
        string memory description = "NFT Threshold Test";
        uint256 votingThreshold = 100 * 10**18; 
        uint32 votingDuration = 7 days;
        
        voteTable.createVoting(description, votingThreshold, votingDuration);
        uint256 newVotingId = currentVotingCount; 
        
        uint256 amount = 1000 * 10**18;
        uint32 stakeDuration = 365 days;
        
        vm.startPrank(user);
        token.approve(address(voteTable), amount);
        voteTable.pledge(newVotingId, amount, stakeDuration, true);
        vm.stopPrank();
        
        assertEq(voteTable.ownerOf(newVotingId), address(voteTable), "NFT should be owned by the contract");
        
        string memory tokenURI = voteTable.tokenURI(newVotingId);
        
        assertTrue(
            bytes(tokenURI).length > 0,
            "Token URI should not be empty"
        );
        
        assertTrue(
            contains(tokenURI, description),
            "Token URI should contain the voting description"
        );
        
        assertTrue(
            contains(tokenURI, "Passed"),
            "Token URI should contain the voting result (Passed)"
        );
    }
    
    function testNFTMintingWithFailedResult() public {
        uint256 currentVotingCount = voteTable.votingCount();
        
        string memory description = "NFT Failed Test";
        uint256 votingThreshold = 1000 * 10**36; 
        uint32 votingDuration = 7 days;
        
        voteTable.createVoting(description, votingThreshold, votingDuration);
        uint256 newVotingId = currentVotingCount;
        
        vm.startPrank(user);
        token.approve(address(voteTable), 1000 * 10**18);
        voteTable.pledge(newVotingId, 1000 * 10**18, 30 days, false);
        vm.stopPrank();
        
        vm.warp(block.timestamp + votingDuration + 1);
        
        (,,,,,bool isActive,) = voteTable.votings(newVotingId);
        assertTrue(isActive, "Voting should be active before finalizing");
        
        voteTable.finalizeVotingByDeadline(newVotingId);
        
        assertEq(voteTable.ownerOf(newVotingId), address(voteTable), "NFT should be owned by the contract");
        
        string memory tokenURI = voteTable.tokenURI(newVotingId);
        
        assertTrue(
            bytes(tokenURI).length > 0,
            "Token URI should not be empty"
        );
        
        assertTrue(
            contains(tokenURI, "Failed"),
            "Token URI should contain the voting result (Failed)"
        );
    }
    
    function testNFTMetadataFormat() public {
        uint256 currentVotingCount = voteTable.votingCount();
        
        string memory description = "Metadata Format Test";
        uint256 votingThreshold = 1000 * 10**36; 
        uint32 votingDuration = 7 days;
        
        voteTable.createVoting(description, votingThreshold, votingDuration);
        uint256 newVotingId = currentVotingCount; 
        
        uint256 forAmount = 1000 * 10**18;
        uint256 againstAmount = 500 * 10**18;
        uint32 stakeDuration = 30 days;
        
        vm.startPrank(user);
        token.approve(address(voteTable), forAmount);
        voteTable.pledge(newVotingId, forAmount, stakeDuration, true); 
        vm.stopPrank();
        
        vm.startPrank(user2);
        token.approve(address(voteTable), againstAmount);
        voteTable.pledge(newVotingId, againstAmount, stakeDuration, false); 
        vm.stopPrank();
        
        vm.warp(block.timestamp + votingDuration + 1);
        
        (,,,,,bool isActive,) = voteTable.votings(newVotingId);
        assertTrue(isActive, "Voting should be active before finalizing");
        
        voteTable.finalizeVotingByDeadline(newVotingId);
        
        string memory tokenURI = voteTable.tokenURI(newVotingId);
        
        uint256 expectedForPower = forAmount * stakeDuration * stakeDuration;
        uint256 expectedAgainstPower = againstAmount * stakeDuration * stakeDuration;
        
        assertTrue(
            contains(tokenURI, '"description":"Metadata Format Test"'),
            "Token URI should contain the description in the correct format"
        );
        
        assertTrue(
            contains(tokenURI, string(abi.encodePacked('"votedFor":', vm.toString(expectedForPower)))),
            "Token URI should contain the correct votedFor value"
        );
        
        assertTrue(
            contains(tokenURI, string(abi.encodePacked('"votedAgainst":', vm.toString(expectedAgainstPower)))),
            "Token URI should contain the correct votedAgainst value"
        );
        
        assertTrue(
            contains(tokenURI, '"result":"Passed"'),
            "Token URI should contain the correct result value"
        );
    }
    
    function testNFTTransferRestriction() public {
        uint256 currentVotingCount = voteTable.votingCount();
        
        string memory description = "NFT Transfer Test";
        uint256 votingThreshold = 100 * 10**18;
        uint32 votingDuration = 7 days;
        
        voteTable.createVoting(description, votingThreshold, votingDuration);
        uint256 newVotingId = currentVotingCount;
        
        uint256 amount = 1000 * 10**18;
        uint32 stakeDuration = 365 days;
        
        vm.startPrank(user);
        token.approve(address(voteTable), amount);
        voteTable.pledge(newVotingId, amount, stakeDuration, true);
        vm.stopPrank();
        
        assertEq(voteTable.ownerOf(newVotingId), address(voteTable), "NFT should be owned by the contract");
        
        vm.startPrank(admin);
        
        vm.expectRevert();
        voteTable.transferFrom(address(voteTable), admin, newVotingId);
        
        vm.stopPrank();
        
        assertEq(voteTable.ownerOf(newVotingId), address(voteTable), "NFT should still be owned by the contract");
    }
} 