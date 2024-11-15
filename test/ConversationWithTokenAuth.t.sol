// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/Conversation.sol";
import "../src/authManagers/TokenHoldingManager.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 token for testing
contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract ConversationWithTokenAuthTest is Test {
    Conversation public conversation;
    TokenHoldingManager public tokenManager;
    MockToken public token;
    
    address public creator = address(1);
    address public voter1 = address(2);
    address public voter2 = address(3);
    
    uint256 public constant DURATION = 7 days;
    uint256 public constant MIN_TOKENS = 100 * 10**18; // 100 tokens
    
    event StatementAdded(uint256 indexed statementId, address indexed author, string content);
    event VoteCast(uint256 indexed statementId, address indexed voter, Conversation.Vote vote);

    function setUp() public {
        // Deploy token and mint to test addresses
        token = new MockToken();
        token.mint(creator, MIN_TOKENS * 2);
        token.mint(voter1, MIN_TOKENS * 2);
        token.mint(voter2, MIN_TOKENS / 2); // Voter2 gets less than minimum
        
        // Deploy token manager
        tokenManager = new TokenHoldingManager(address(token), MIN_TOKENS);
        
        // Deploy conversation with token manager
        conversation = new Conversation(
            "Test Conversation",
            "Test Description",
            creator,
            DURATION,
            address(tokenManager)
        );
    }

    function testTokenBasedParticipation() public {
        // Creator should be able to add statement
        vm.startPrank(creator);
        uint256 statementId = conversation.addStatement("Test Statement");
        vm.stopPrank();

        // Voter1 should be able to vote (has enough tokens)
        vm.prank(voter1);
        conversation.vote(statementId, Conversation.Vote.Agree);

        // Voter2 should not be able to vote (insufficient tokens)
        vm.startPrank(voter2);
        vm.expectRevert("Must be whitelisted");
        conversation.vote(statementId, Conversation.Vote.Agree);
        vm.stopPrank();
    }

    function testParticipationAfterTokenTransfer() public {
        // First add a statement
        vm.prank(creator);
        uint256 statementId = conversation.addStatement("Test Statement");

        // Initially voter2 cannot participate
        vm.prank(voter2);
        vm.expectRevert("Must be whitelisted");
        conversation.vote(statementId, Conversation.Vote.Agree);

        // Transfer tokens to voter2
        vm.prank(voter1);
        token.transfer(voter2, MIN_TOKENS);

        // Now voter2 should be able to participate
        vm.prank(voter2);
        conversation.vote(statementId, Conversation.Vote.Agree);
    }

    function testLoseParticipationRights() public {
        // First add a statement
        vm.prank(creator);
        uint256 statementId = conversation.addStatement("Test Statement");

        // Transfer tokens away from voter1
        vm.startPrank(voter1);
        token.transfer(address(0xdead), MIN_TOKENS * 2);

        // Voter1 should no longer be able to participate
        vm.expectRevert("Must be whitelisted");
        conversation.vote(statementId, Conversation.Vote.Agree);
        vm.stopPrank();
    }

    function testMulticallWithTokenAuth() public {
        // Add statements as creator
        vm.startPrank(creator);
        uint256 statement1 = conversation.addStatement("Statement 1");
        uint256 statement2 = conversation.addStatement("Statement 2");
        vm.stopPrank();

        // Prepare multicall data
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(
            conversation.vote.selector,
            statement1,
            Conversation.Vote.Agree
        );
        calls[1] = abi.encodeWithSelector(
            conversation.vote.selector,
            statement2,
            Conversation.Vote.Disagree
        );

        // Should work for voter1 (has enough tokens)
        vm.prank(voter1);
        conversation.multicall(calls);

        // Should fail for voter2 (insufficient tokens)
        vm.prank(voter2);
        vm.expectRevert("Must be whitelisted");
        conversation.multicall(calls);
    }

    function testTokenBalanceFluctuation() public {
        // Add statement
        vm.prank(creator);
        uint256 statementId = conversation.addStatement("Test Statement");

        // Start with voter1 who has enough tokens
        vm.startPrank(voter1);
        
        // Transfer tokens to temporarily go below minimum
        token.transfer(address(0xdead), MIN_TOKENS * 2 - MIN_TOKENS/2);
        
        // Should fail to vote with insufficient balance
        vm.expectRevert("Must be whitelisted");
        conversation.vote(statementId, Conversation.Vote.Agree);

        // Receive tokens back
        vm.stopPrank();
        vm.prank(creator);
        token.transfer(voter1, MIN_TOKENS);

        // Should be able to vote again
        vm.prank(voter1);
        conversation.vote(statementId, Conversation.Vote.Agree);
    }

    function testCreatorNeedsTokens() public {
        // Transfer all tokens away from creator
        vm.startPrank(creator);
        token.transfer(address(0xdead), MIN_TOKENS * 2);

        // Creator should not be able to add statement without tokens
        vm.expectRevert("Must be whitelisted");
        conversation.addStatement("Test Statement");
        vm.stopPrank();
    }

    function testParticipationWithExactMinimum() public {
        // Setup user with exact minimum tokens
        address user = address(4);
        token.mint(user, MIN_TOKENS);

        // Should be able to participate
        vm.startPrank(user);
        uint256 statementId = conversation.addStatement("Test Statement");
        
        // Transfer 1 token away
        token.transfer(address(0xdead), 1);
        
        // Should now fail
        vm.expectRevert("Must be whitelisted");
        conversation.vote(statementId, Conversation.Vote.Agree);
        vm.stopPrank();
    }
} 