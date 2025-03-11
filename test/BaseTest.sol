// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {VoteTable} from "../src/VoteTable.sol";
import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract BaseTest is Test {
    VoteTable public voteTable;
    ERC20Mock public token;
    address public admin;
    address public user;
    address public user2;
    uint256 public votingId;

    function setUp() public virtual {
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

    function contains(string memory _string, string memory _substring) internal pure returns (bool) {
        bytes memory stringBytes = bytes(_string);
        bytes memory substringBytes = bytes(_substring);
        
        if (substringBytes.length > stringBytes.length) {
            return false;
        }
        
        for (uint i = 0; i <= stringBytes.length - substringBytes.length; i++) {
            bool found = true;
            
            for (uint j = 0; j < substringBytes.length; j++) {
                if (stringBytes[i + j] != substringBytes[j]) {
                    found = false;
                    break;
                }
            }
            
            if (found) {
                return true;
            }
        }
        
        return false;
    }
} 