// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/authManagers/TokenHoldingManager.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// Mock ERC20 token for testing
contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

// Add after the existing MockToken contract
contract MockNFT is ERC721 {
    uint256 private _nextTokenId;

    constructor() ERC721("Mock NFT", "MNFT") {}

    function mint(address to) external returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _mint(to, tokenId);
        return tokenId;
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

    function testWithNFT() public {
        // Deploy NFT contract
        MockNFT nft = new MockNFT();
        
        // Deploy manager with NFT
        TokenHoldingManager nftManager = new TokenHoldingManager(
            address(nft),
            1  // Require at least 1 NFT
        );

        // Initially user should not be whitelisted
        assertFalse(nftManager.isWhitelisted(user1));
        
        // Mint NFT to user1
        nft.mint(user1);
        assertTrue(nftManager.isWhitelisted(user1));
        
        // Transfer NFT to user2
        vm.startPrank(user1);
        nft.transferFrom(user1, user2, 0);
        vm.stopPrank();
        
        assertFalse(nftManager.isWhitelisted(user1));
        assertTrue(nftManager.isWhitelisted(user2));
    }

    function testMultipleNFTs() public {
        MockNFT nft = new MockNFT();
        TokenHoldingManager nftManager = new TokenHoldingManager(
            address(nft),
            2  // Require at least 2 NFTs
        );

        // Mint one NFT
        nft.mint(user1);
        assertFalse(nftManager.isWhitelisted(user1));

        // Mint second NFT
        nft.mint(user1);
        assertTrue(nftManager.isWhitelisted(user1));

        // Transfer one away
        vm.startPrank(user1);
        nft.transferFrom(user1, user2, 0);
        vm.stopPrank();

        assertFalse(nftManager.isWhitelisted(user1));
        assertFalse(nftManager.isWhitelisted(user2));
    }

    function testNFTBatchTransfers() public {
        MockNFT nft = new MockNFT();
        TokenHoldingManager nftManager = new TokenHoldingManager(
            address(nft),
            3  // Require 3 NFTs
        );

        // Mint 3 NFTs to user1
        nft.mint(user1);
        nft.mint(user1);
        nft.mint(user1);
        assertTrue(nftManager.isWhitelisted(user1));

        // Transfer all NFTs to user2
        vm.startPrank(user1);
        nft.transferFrom(user1, user2, 0);
        nft.transferFrom(user1, user2, 1);
        nft.transferFrom(user1, user2, 2);
        vm.stopPrank();

        assertFalse(nftManager.isWhitelisted(user1));
        assertTrue(nftManager.isWhitelisted(user2));
    }

    function testMixedNFTOwnership() public {
        MockNFT nft = new MockNFT();
        TokenHoldingManager nftManager = new TokenHoldingManager(
            address(nft),
            2  // Require 2 NFTs
        );

        // Mint 3 NFTs total
        nft.mint(user1); // ID 0
        nft.mint(user1); // ID 1
        nft.mint(user2); // ID 2

        assertTrue(nftManager.isWhitelisted(user1));
        assertFalse(nftManager.isWhitelisted(user2));

        // Transfer one from user1 to user2
        vm.prank(user1);
        nft.transferFrom(user1, user2, 0);

        assertFalse(nftManager.isWhitelisted(user1));
        assertTrue(nftManager.isWhitelisted(user2));
    }

    function testNFTBurning() public {
        MockNFT nft = new MockNFT();
        TokenHoldingManager nftManager = new TokenHoldingManager(
            address(nft),
            1  // Require 1 NFT
        );

        // Mint NFT to user1
        uint256 tokenId = nft.mint(user1);
        assertTrue(nftManager.isWhitelisted(user1));

        // Burn NFT (transfer to zero address)
        vm.prank(user1);
        nft.transferFrom(user1, address(0xdead), tokenId);
        assertFalse(nftManager.isWhitelisted(user1));
    }
} 