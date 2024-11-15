// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/authManagers/TokenHoldingManager.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 token for testing
contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract TokenHoldingManagerTest is Test {
    TokenHoldingManager public manager;
    MockToken public token;
    
    address public user1 = address(1);
    address public user2 = address(2);
    
    uint256 public constant MIN_BALANCE = 100 * 10**18; // 100 tokens
    
    function setUp() public {
        // Deploy mock token
        token = new MockToken();
        
        // Deploy TokenHoldingManager
        manager = new TokenHoldingManager(address(token), MIN_BALANCE);
    }

    function testConstructor() public {
        assertEq(manager.token(), address(token));
        assertEq(manager.minBalance(), MIN_BALANCE);
    }

    function testConstructorZeroAddress() public {
        vm.expectRevert("Token address cannot be 0");
        new TokenHoldingManager(address(0), MIN_BALANCE);
    }

    function testIsWhitelisted() public {
        // Initially user should not be whitelisted
        assertFalse(manager.isWhitelisted(user1));
        
        // Mint exactly minimum balance
        token.mint(user1, MIN_BALANCE);
        assertTrue(manager.isWhitelisted(user1));
        
        // Mint less than minimum balance to user2
        token.mint(user2, MIN_BALANCE - 1);
        assertFalse(manager.isWhitelisted(user2));
    }

    function testWhitelistingWithTransfers() public {
        // Mint tokens to user1
        token.mint(user1, MIN_BALANCE * 2);
        assertTrue(manager.isWhitelisted(user1));
        
        // Transfer tokens as user1
        vm.startPrank(user1);
        
        // Transfer to user2, keeping enough balance
        token.transfer(user2, MIN_BALANCE);
        assertTrue(manager.isWhitelisted(user1));
        assertTrue(manager.isWhitelisted(user2));
        
        // Transfer more tokens, going below minimum
        token.transfer(user2, 1);
        assertFalse(manager.isWhitelisted(user1));
        assertTrue(manager.isWhitelisted(user2));
        
        vm.stopPrank();
    }

    function testWhitelistingWithZeroBalance() public {
        assertFalse(manager.isWhitelisted(user1));
        
        // Mint small amount
        token.mint(user1, 1);
        assertFalse(manager.isWhitelisted(user1));
    }

    function testWhitelistingWithLargeBalance() public {
        // Mint large amount
        token.mint(user1, MIN_BALANCE * 1000);
        assertTrue(manager.isWhitelisted(user1));
    }

    function testWhitelistingAfterBurning() public {
        // Mint tokens to user1
        token.mint(user1, MIN_BALANCE * 2);
        assertTrue(manager.isWhitelisted(user1));
        
        // Simulate token burning by transferring to address(0)
        vm.startPrank(user1);
        token.transfer(address(0xdead), MIN_BALANCE + 1);
        assertFalse(manager.isWhitelisted(user1));
        vm.stopPrank();
    }

    function testMultipleUsersWhitelisting() public {
        address[] memory users = new address[](5);
        for(uint i = 0; i < 5; i++) {
            users[i] = address(uint160(i + 1));
            token.mint(users[i], MIN_BALANCE + i * 1e18);
        }

        for(uint i = 0; i < 5; i++) {
            assertTrue(manager.isWhitelisted(users[i]));
        }
    }

    function testBalanceJustBelowMinimum() public {
        token.mint(user1, MIN_BALANCE - 1);
        assertFalse(manager.isWhitelisted(user1));
        
        // Add 1 more token to reach minimum
        token.mint(user1, 1);
        assertTrue(manager.isWhitelisted(user1));
    }

    function testBalanceFluctuationAroundMinimum() public {
        // Start with minimum balance
        token.mint(user1, MIN_BALANCE);
        assertTrue(manager.isWhitelisted(user1));
        
        vm.startPrank(user1);
        
        // Transfer 1 token away
        token.transfer(user2, 1);
        assertFalse(manager.isWhitelisted(user1));
        
        // Receive 1 token back
        vm.stopPrank();
        vm.prank(user2);
        token.transfer(user1, 1);
        assertTrue(manager.isWhitelisted(user1));
    }
} 