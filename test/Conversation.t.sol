// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
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

contract ConversationTest is Test {
    Conversation public conversation;
    MockAuthManager public authManager;
    
    address public creator = address(1);
    address public voter1 = address(2);
    address public voter2 = address(3);
    
    uint256 public constant DURATION = 7 days;
    
    event StatementAdded(uint256 indexed statementId, address indexed author, string content);
    event VoteCast(uint256 indexed statementId, address indexed voter, Conversation.Vote vote);

    function setUp() public {
        authManager = new MockAuthManager();
        
        // Whitelist test addresses
        authManager.setWhitelisted(creator, true);
        authManager.setWhitelisted(voter1, true);
        authManager.setWhitelisted(voter2, true);
        
        conversation = new Conversation(
            "Test Conversation",
            "Test Description",
            creator,
            DURATION,
            address(authManager)
        );
    }

    function testInitialState() public {
        assertEq(conversation.title(), "Test Conversation");
        assertEq(conversation.description(), "Test Description");
        assertEq(conversation.creator(), creator);
        assertEq(conversation.statementCount(), 0);
        assertEq(conversation.deadline(), block.timestamp + DURATION);
        assertEq(conversation.authManager(), address(authManager));
    }

    function testAddStatement() public {
        vm.startPrank(creator);
        
        uint256 statementId = conversation.addStatement("Test Statement");
        assertEq(statementId, 0);
        
        (address author, string memory content, uint256 agreeCount, uint256 disagreeCount, uint256 timestamp) = 
            conversation.statements(statementId);
            
        assertEq(author, creator);
        assertEq(content, "Test Statement");
        assertEq(agreeCount, 0);
        assertEq(disagreeCount, 0);
        assertEq(timestamp, block.timestamp);
        
        vm.stopPrank();
    }

    function testCannotAddEmptyStatement() public {
        vm.prank(creator);
        vm.expectRevert("Content cannot be empty");
        conversation.addStatement("");
    }

    function testVoting() public {
        // First add a statement
        vm.prank(creator);
        uint256 statementId = conversation.addStatement("Test Statement");
        
        // Test voting
        vm.startPrank(voter1);
        conversation.vote(statementId, Conversation.VoteType.Agree);
        
        (,, uint256 agreeCount, uint256 disagreeCount,) = conversation.statements(statementId);
        assertEq(agreeCount, 1);
        assertEq(disagreeCount, 0);

        // Verify vote data
        Conversation.Vote[] memory votes = conversation.getVotesData(voter1);
        assertEq(votes.length, 1);
        assertEq(uint256(votes[0].vote), uint256(Conversation.VoteType.Agree));
        assertEq(votes[0].voter, voter1);
        assertEq(votes[0].statementId, statementId);
        
        vm.stopPrank();
    }

    function testCannotVoteTwice() public {
        vm.prank(creator);
        uint256 statementId = conversation.addStatement("Test Statement");
        
        vm.startPrank(voter1);
        conversation.vote(statementId, Conversation.VoteType.Agree);
        
        vm.expectRevert("Already voted");
        conversation.vote(statementId, Conversation.VoteType.Disagree);
        vm.stopPrank();
    }

    function testCannotVoteAfterDeadline() public {
        vm.prank(creator);
        uint256 statementId = conversation.addStatement("Test Statement");
        
        // Move time past deadline
        vm.warp(block.timestamp + DURATION + 1);
        
        vm.prank(voter1);
        vm.expectRevert("Deadline has passed");
        conversation.vote(statementId, Conversation.VoteType.Agree);
    }

    function testCannotAddStatementAfterDeadline() public {
        // Move time past deadline
        vm.warp(block.timestamp + DURATION + 1);
        
        vm.prank(creator);
        vm.expectRevert("Deadline has passed");
        conversation.addStatement("Test Statement");
    }

    function testOnlyWhitelistedCanParticipate() public {
        address nonWhitelisted = address(4);
        
        vm.startPrank(nonWhitelisted);
        
        vm.expectRevert("Must be whitelisted");
        conversation.addStatement("Test Statement");
        
        // First add a statement from whitelisted user
        vm.stopPrank();
        vm.prank(creator);
        uint256 statementId = conversation.addStatement("Test Statement");
        
        // Try to vote as non-whitelisted
        vm.prank(nonWhitelisted);
        vm.expectRevert("Must be whitelisted");
        conversation.vote(statementId, Conversation.VoteType.Agree);
    }

    function testMultipleVoters() public {
        // Add statement
        vm.prank(creator);
        uint256 statementId = conversation.addStatement("Test Statement");
        
        // First voter agrees
        vm.prank(voter1);
        conversation.vote(statementId, Conversation.VoteType.Agree);
        
        // Second voter disagrees
        vm.prank(voter2);
        conversation.vote(statementId, Conversation.VoteType.Disagree);
        
        (,, uint256 agreeCount, uint256 disagreeCount,) = conversation.statements(statementId);
        assertEq(agreeCount, 1);
        assertEq(disagreeCount, 1);

        // Verify votes data
        Conversation.Vote[] memory votes1 = conversation.getVotesData(voter1);
        Conversation.Vote[] memory votes2 = conversation.getVotesData(voter2);
        
        assertEq(votes1.length, 1);
        assertEq(votes2.length, 1);
        assertEq(uint256(votes1[0].vote), uint256(Conversation.VoteType.Agree));
        assertEq(uint256(votes2[0].vote), uint256(Conversation.VoteType.Disagree));
    }

    function testMulticallVoting() public {
        // First add multiple statements
        vm.startPrank(creator);
        uint256 statement1 = conversation.addStatement("Statement 1");
        uint256 statement2 = conversation.addStatement("Statement 2");
        uint256 statement3 = conversation.addStatement("Statement 3");
        vm.stopPrank();

        // Prepare multicall data for voting on all statements
        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeWithSelector(
            conversation.vote.selector,
            statement1,
            Conversation.VoteType.Agree
        );
        calls[1] = abi.encodeWithSelector(
            conversation.vote.selector,
            statement2,
            Conversation.VoteType.Disagree
        );
        calls[2] = abi.encodeWithSelector(
            conversation.vote.selector,
            statement3,
            Conversation.VoteType.Agree
        );

        // Execute multicall as voter1
        vm.prank(voter1);
        conversation.multicall(calls);

        // Verify votes were recorded correctly
        Conversation.Vote[] memory votes = conversation.getVotesData(voter1);
        assertEq(votes.length, 3);
        assertEq(uint256(votes[0].vote), uint256(Conversation.VoteType.Agree));
        assertEq(uint256(votes[1].vote), uint256(Conversation.VoteType.Disagree));
        assertEq(uint256(votes[2].vote), uint256(Conversation.VoteType.Agree));

        // Verify vote counts
        (,, uint256 agree1, uint256 disagree1,) = conversation.statements(statement1);
        (,, uint256 agree2, uint256 disagree2,) = conversation.statements(statement2);
        (,, uint256 agree3, uint256 disagree3,) = conversation.statements(statement3);

        assertEq(agree1, 1);
        assertEq(disagree1, 0);
        assertEq(agree2, 0);
        assertEq(disagree2, 1);
        assertEq(agree3, 1);
        assertEq(disagree3, 0);
    }

    function testMulticallVotingFailure() public {
        // First add a statement
        vm.prank(creator);
        uint256 statement1 = conversation.addStatement("Statement 1");

        // Prepare multicall data with duplicate votes (should fail)
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(
            conversation.vote.selector,
            statement1,
            Conversation.VoteType.Agree
        );
        calls[1] = abi.encodeWithSelector(
            conversation.vote.selector,
            statement1,
            Conversation.VoteType.Disagree  // This should fail as we can't vote twice
        );

        // Execute multicall as voter1
        vm.prank(voter1);
        vm.expectRevert("Already voted");
        conversation.multicall(calls);

        // Verify no votes were recorded (transaction should have reverted)
        Conversation.Vote[] memory votes = conversation.getVotesData(voter1);
        assertEq(votes.length, 0);
    }
}
