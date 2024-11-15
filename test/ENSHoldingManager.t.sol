// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/authManagers/ENSHoldingManager.sol";

contract MockResolver {
    mapping(bytes32 => string) private names;

    function setName(bytes32 node, string memory name) external {
        names[node] = name;
    }

    function name(bytes32 node) external view returns (string memory) {
        return names[node];
    }
}

contract MockReverseRegistrar {
    INameResolver public defaultResolver;

    constructor(address _resolver) {
        defaultResolver = INameResolver(_resolver);
    }

    function node(address addr) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(addr));
    }

    function setDefaultResolver(address _resolver) external {
        defaultResolver = INameResolver(_resolver);
    }
}

contract ENSHoldingManagerTest is Test {
    ENSHoldingManager public manager;
    MockReverseRegistrar public reverseRegistrar;
    MockResolver public resolver;
    
    address public user1 = address(1);
    address public user2 = address(2);
    
    function setUp() public {
        // Deploy mock contracts
        resolver = new MockResolver();
        reverseRegistrar = new MockReverseRegistrar(address(resolver));
        
        // Deploy ENSHoldingManager
        manager = new ENSHoldingManager(address(reverseRegistrar));
    }

    function testConstructor() public {
        assertEq(address(manager.reverseRegistrar()), address(reverseRegistrar));
    }

    function testConstructorZeroAddress() public {
        vm.expectRevert("Reverse registrar cannot be 0");
        new ENSHoldingManager(address(0));
    }

    function testIsWhitelisted() public {
        // Initially no users should be whitelisted
        assertFalse(manager.isWhitelisted(user1));
        assertFalse(manager.isWhitelisted(user2));
        
        // Set ENS name for user1
        bytes32 node = reverseRegistrar.node(user1);
        resolver.setName(node, "user1.eth");
        
        // Now user1 should be whitelisted
        assertTrue(manager.isWhitelisted(user1));
        assertFalse(manager.isWhitelisted(user2));
    }

    function testEmptyName() public {
        bytes32 node = reverseRegistrar.node(user1);
        
        // Set empty name
        resolver.setName(node, "");
        assertFalse(manager.isWhitelisted(user1));
    }

    function testChangeResolver() public {
        bytes32 node = reverseRegistrar.node(user1);
        resolver.setName(node, "user1.eth");
        assertTrue(manager.isWhitelisted(user1));
        
        // Deploy new resolver and switch to it
        MockResolver newResolver = new MockResolver();
        reverseRegistrar.setDefaultResolver(address(newResolver));
        
        // User should no longer be whitelisted
        assertFalse(manager.isWhitelisted(user1));
        
        // Set name in new resolver
        newResolver.setName(node, "user1.eth");
        assertTrue(manager.isWhitelisted(user1));
    }

    function testMultipleUsers() public {
        address[] memory users = new address[](3);
        for(uint i = 0; i < 3; i++) {
            users[i] = address(uint160(i + 1));
            bytes32 node = reverseRegistrar.node(users[i]);
            resolver.setName(node, string(abi.encodePacked("user", vm.toString(i + 1), ".eth")));
        }

        for(uint i = 0; i < 3; i++) {
            assertTrue(manager.isWhitelisted(users[i]));
        }
    }
} 