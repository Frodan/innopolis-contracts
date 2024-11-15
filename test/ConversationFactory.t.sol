// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/ConversationFactory.sol";
import "../src/Conversation.sol";
import "../src/interfaces/IAuthManager.sol";

contract MockAuthManager is IAuthManager {
    mapping(address => bool) public whitelisted;

    function setWhitelisted(address user, bool status) external {
        whitelisted[user] = status;
    }

    function isWhitelisted(address user) external view returns (bool) {
        return whitelisted[user];
    }
}

contract ConversationFactoryTest is Test {
    ConversationFactory public factory;
    MockAuthManager public authManager;
    
    address public creator1 = address(1);
    address public creator2 = address(2);
    
    uint256 public constant DURATION = 7 days;
    
    event ConversationCreated(address indexed conversationAddress, address indexed creator);

    function setUp() public {
        factory = new ConversationFactory();
        authManager = new MockAuthManager();
        
        // Whitelist test addresses
        authManager.setWhitelisted(creator1, true);
        authManager.setWhitelisted(creator2, true);
    }

    function testCreateConversation() public {
        vm.startPrank(creator1);

        address conversationAddr = factory.createConversation(
            "Test Conversation",
            "Test Description",
            address(authManager),
            DURATION
        );
        
        Conversation conversation = Conversation(conversationAddr);
        
        assertEq(conversation.title(), "Test Conversation");
        assertEq(conversation.description(), "Test Description");
        assertEq(conversation.creator(), creator1);
        assertEq(conversation.deadline(), block.timestamp + DURATION);
        assertEq(conversation.authManager(), address(authManager));
        
        vm.stopPrank();
    }

    function testGetConversationCount() public {
        assertEq(factory.getConversationCount(), 0);
        
        vm.startPrank(creator1);
        
        factory.createConversation("Conv 1", "Desc 1", address(authManager), DURATION);
        assertEq(factory.getConversationCount(), 1);
        
        factory.createConversation("Conv 2", "Desc 2", address(authManager), DURATION);
        assertEq(factory.getConversationCount(), 2);
        
        vm.stopPrank();
    }

    function testGetConversationsByCreator() public {
        // Create conversations from creator1
        vm.startPrank(creator1);
        address conv1 = factory.createConversation("Conv 1", "Desc 1", address(authManager), DURATION);
        address conv2 = factory.createConversation("Conv 2", "Desc 2", address(authManager), DURATION);
        vm.stopPrank();
        
        // Create conversation from creator2
        vm.prank(creator2);
        address conv3 = factory.createConversation("Conv 3", "Desc 3", address(authManager), DURATION);
        
        // Get conversations for creator1
        address[] memory creator1Convs = factory.getConversationsByCreator(creator1);
        assertEq(creator1Convs.length, 2);
        assertEq(creator1Convs[0], conv1);
        assertEq(creator1Convs[1], conv2);
        
        // Get conversations for creator2
        address[] memory creator2Convs = factory.getConversationsByCreator(creator2);
        assertEq(creator2Convs.length, 1);
        assertEq(creator2Convs[0], conv3);
    }

    function testGetConversationsByCreatorEmpty() public {
        address[] memory emptyConvs = factory.getConversationsByCreator(creator1);
        assertEq(emptyConvs.length, 0);
    }

    function testMultipleConversationsWithSameTitle() public {
        vm.startPrank(creator1);
        
        address conv1 = factory.createConversation("Same Title", "Desc 1", address(authManager), DURATION);
        address conv2 = factory.createConversation("Same Title", "Desc 2", address(authManager), DURATION);
        
        assertTrue(conv1 != conv2);
        assertEq(Conversation(conv1).title(), "Same Title");
        assertEq(Conversation(conv2).title(), "Same Title");
        
        vm.stopPrank();
    }

    function testConversationsArray() public {
        vm.startPrank(creator1);
        
        address conv1 = factory.createConversation("Conv 1", "Desc 1", address(authManager), DURATION);
        address conv2 = factory.createConversation("Conv 2", "Desc 2", address(authManager), DURATION);
        
        assertEq(factory.conversations(0), conv1);
        assertEq(factory.conversations(1), conv2);
        
        vm.stopPrank();
    }

    function testCreateConversationWithZeroAuthManager() public {
        vm.prank(creator1);
        
        address conversationAddr = factory.createConversation(
            "Test Conversation",
            "Test Description",
            address(0),  // Zero address for auth manager
            DURATION
        );
        
        Conversation conversation = Conversation(conversationAddr);
        assertEq(conversation.authManager(), address(0));
    }

    function testCreateConversationWithZeroDuration() public {
        vm.prank(creator1);
        
        address conversationAddr = factory.createConversation(
            "Test Conversation",
            "Test Description",
            address(authManager),
            0  // Zero duration
        );
        
        Conversation conversation = Conversation(conversationAddr);
        assertEq(conversation.deadline(), block.timestamp);
    }
}
