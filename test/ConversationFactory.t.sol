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

    function testCreateENSHoldingManager() public {
        address reverseRegistrar = address(0x123); // Mock address
        
        vm.prank(creator1);
        address ensManager = factory.createENSHoldingManager(reverseRegistrar);
        
        // Verify the manager was created correctly
        ENSHoldingManager manager = ENSHoldingManager(ensManager);
        assertEq(address(manager.reverseRegistrar()), reverseRegistrar);
    }

    function testCreateENSHoldingManagerZeroAddress() public {
        vm.prank(creator1);
        vm.expectRevert("Reverse registrar cannot be 0");
        factory.createENSHoldingManager(address(0));
    }

    function testCreateTokenHoldingManager() public {
        address token = address(0x456); // Mock token address
        uint256 minBalance = 100 * 10**18;
        
        vm.prank(creator1);
        address tokenManager = factory.createTokenHoldingManager(token, minBalance);
        
        // Verify the manager was created correctly
        TokenHoldingManager manager = TokenHoldingManager(tokenManager);
        assertEq(manager.token(), token);
        assertEq(manager.minBalance(), minBalance);
    }

    function testCreateTokenHoldingManagerZeroAddress() public {
        vm.prank(creator1);
        vm.expectRevert("Token address cannot be 0");
        factory.createTokenHoldingManager(address(0), 100 * 10**18);
    }

    function testCreateManagersWithDifferentUsers() public {
        address token = address(0x456);
        address reverseRegistrar = address(0x123);
        
        // Creator1 creates managers
        vm.prank(creator1);
        address tokenManager1 = factory.createTokenHoldingManager(token, 100 * 10**18);
        
        vm.prank(creator1);
        address ensManager1 = factory.createENSHoldingManager(reverseRegistrar);
        
        // Creator2 creates managers
        vm.prank(creator2);
        address tokenManager2 = factory.createTokenHoldingManager(token, 200 * 10**18);
        
        vm.prank(creator2);
        address ensManager2 = factory.createENSHoldingManager(reverseRegistrar);
        
        // Verify all managers are different
        assertTrue(tokenManager1 != tokenManager2);
        assertTrue(ensManager1 != ensManager2);
        
        // Verify configurations
        assertEq(TokenHoldingManager(tokenManager1).minBalance(), 100 * 10**18);
        assertEq(TokenHoldingManager(tokenManager2).minBalance(), 200 * 10**18);
        assertEq(address(ENSHoldingManager(ensManager1).reverseRegistrar()), reverseRegistrar);
        assertEq(address(ENSHoldingManager(ensManager2).reverseRegistrar()), reverseRegistrar);
    }

    function testCreateManagerAndUseInConversation() public {
        address token = address(0x456);
        uint256 minBalance = 100 * 10**18;
        
        vm.startPrank(creator1);
        
        // Create token manager
        address tokenManager = factory.createTokenHoldingManager(token, minBalance);
        
        // Create conversation with the manager
        address conversation = factory.createConversation(
            "Token Gated Conversation",
            "Only for token holders",
            tokenManager,
            7 days
        );
        
        vm.stopPrank();
        
        // Verify the conversation uses the correct manager
        assertEq(Conversation(conversation).authManager(), tokenManager);
    }

    function testCreateETHBalanceManager() public {
        uint256 minBalance = 1 ether;
        
        vm.prank(creator1);
        address ethManager = factory.createETHBalanceManager(minBalance);
        
        // Verify the manager was created correctly
        ETHBalanceManager manager = ETHBalanceManager(ethManager);
        assertEq(manager.minBalance(), minBalance);
    }

    function testCreateETHBalanceManagerZeroBalance() public {
        vm.prank(creator1);
        vm.expectRevert("Minimum balance must be greater than 0");
        factory.createETHBalanceManager(0);
    }

    function testCreateETHManagerAndUseInConversation() public {
        uint256 minBalance = 1 ether;
        
        vm.startPrank(creator1);
        
        // Create ETH manager
        address ethManager = factory.createETHBalanceManager(minBalance);
        
        // Create conversation with the manager
        address conversation = factory.createConversation(
            "ETH Gated Conversation",
            "Only for ETH holders",
            ethManager,
            7 days
        );
        
        vm.stopPrank();
        
        // Verify the conversation uses the correct manager
        assertEq(Conversation(conversation).authManager(), ethManager);
    }
}
