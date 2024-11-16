// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/authManagers/ETHBalanceManager.sol";

contract ETHBalanceManagerTest is Test {
    ETHBalanceManager public manager;
    
    address public user1 = address(1);
    address public user2 = address(2);
    
    uint256 public constant MIN_BALANCE = 1 ether;
    
    function setUp() public {
        manager = new ETHBalanceManager(MIN_BALANCE);
    }

    function testConstructor() public {
        assertEq(manager.minBalance(), MIN_BALANCE);
    }

    function testConstructorZeroBalance() public {
        vm.expectRevert("Minimum balance must be greater than 0");
        new ETHBalanceManager(0);
    }

    function testIsWhitelisted() public {
        // Initially users should not be whitelisted
        assertFalse(manager.isWhitelisted(user1));
        assertFalse(manager.isWhitelisted(user2));
        
        // Give user1 exactly minimum balance
        vm.deal(user1, MIN_BALANCE);
        assertTrue(manager.isWhitelisted(user1));
        
        // Give user2 less than minimum
        vm.deal(user2, MIN_BALANCE - 1);
        assertFalse(manager.isWhitelisted(user2));
    }

    function testBalanceFluctuation() public {
        // Start with more than minimum
        vm.deal(user1, MIN_BALANCE * 2);
        assertTrue(manager.isWhitelisted(user1));
        
        // Reduce balance below minimum
        vm.prank(user1);
        payable(user2).transfer(MIN_BALANCE + 1);
        assertFalse(manager.isWhitelisted(user1));
        assertTrue(manager.isWhitelisted(user2));
    }

    function testExactMinimumBalance() public {
        // Give exact minimum balance
        vm.deal(user1, MIN_BALANCE);
        assertTrue(manager.isWhitelisted(user1));
        
        // Send 1 wei away
        vm.prank(user1);
        payable(user2).transfer(1);
        assertFalse(manager.isWhitelisted(user1));
    }

    function testMultipleUsers() public {
        address[] memory users = new address[](5);
        for(uint i = 0; i < 5; i++) {
            users[i] = address(uint160(i + 1));
            vm.deal(users[i], MIN_BALANCE + i * 0.1 ether);
        }

        for(uint i = 0; i < 5; i++) {
            assertTrue(manager.isWhitelisted(users[i]));
        }
    }

    function testHighMinimumBalance() public {
        // Test with a very high minimum balance
        uint256 highMin = 1000 ether;
        ETHBalanceManager highManager = new ETHBalanceManager(highMin);
        
        // Even with 999 ETH, should not be whitelisted
        vm.deal(user1, 999 ether);
        assertFalse(highManager.isWhitelisted(user1));
        
        // With 1000 ETH, should be whitelisted
        vm.deal(user1, 1000 ether);
        assertTrue(highManager.isWhitelisted(user1));
    }
} 