// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/Multicall.sol";
import "./interfaces/IAuthManager.sol";
/**
 * @title Conversation
 * @dev Manages statements and votes for a pol.is-like conversation
 */
contract Conversation is Multicall {
    // Structs
    struct Statement {
        address author;
        string content;
        uint256 agreeCount;
        uint256 disagreeCount;
        uint256 timestamp;
    }

    enum Vote {
        Neutral,
        Agree,
        Disagree
    }

    // State variables
    string public title;
    string public description;
    address public creator;
    uint256 public statementCount;
    uint256 public deadline;
    address public authManager;
    
    // Mappings
    mapping(uint256 => Statement) public statements;

    // Votes, statementId -> voter -> vote
    mapping(uint256 => mapping(address => Vote)) public votes;
    
    // Events
    event StatementAdded(uint256 indexed statementId, address indexed author, string content);
    event VoteCast(uint256 indexed statementId, address indexed voter, Vote vote);

    modifier onlyWhitelisted() {
        if (authManager != address(0)) {
            require(IAuthManager(authManager).isWhitelisted(msg.sender), "Must be whitelisted");
        }
        _;
    }
    

    constructor(
        string memory _title,
        string memory _description,
        address _creator,
        uint256 _duration,
        address _authManager
    ) {
        title = _title;
        description = _description;
        creator = _creator;
        deadline = block.timestamp + _duration;
        authManager = _authManager;
    }


    /**
     * @dev Adds a new statement to the conversation
     * @param _content The content of the statement
     * @return statementId The ID of the newly created statement
     */
    function addStatement(string memory _content) external onlyWhitelisted returns (uint256) {
        require(bytes(_content).length > 0, "Content cannot be empty");
        require(block.timestamp < deadline, "Deadline has passed");
        
        uint256 statementId = statementCount++;
        statements[statementId] = Statement({
            author: msg.sender,
            content: _content,
            agreeCount: 0,
            disagreeCount: 0,
            timestamp: block.timestamp
        });

        emit StatementAdded(statementId, msg.sender, _content);
        return statementId;
    }


    /**
     * @dev Allows a participant to vote on a statement
     * @param _statementId The ID of the statement to vote on
     * @param _vote The vote to cast
     */
    function vote(uint256 _statementId, Vote _vote) external onlyWhitelisted {
        require(block.timestamp < deadline, "Deadline has passed");
        require(_statementId < statementCount, "Statement does not exist");
        require(votes[_statementId][msg.sender] == Vote.Neutral, "Already voted");

        Statement storage statement = statements[_statementId];

        // Record new vote
        votes[_statementId][msg.sender] = _vote;

        // Update vote counts
        if (_vote == Vote.Agree) {
            statement.agreeCount++;
        } else if (_vote == Vote.Disagree) {
            statement.disagreeCount++;
        }

        emit VoteCast(_statementId, msg.sender, _vote);
    }
}
