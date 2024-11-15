// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./Conversation.sol";
import "./interfaces/IAuthManager.sol";

/**
 * @title ConversationFactory
 * @dev Factory contract for creating and managing Conversation instances
 */
contract ConversationFactory {
    // Array to store all created conversation addresses
    address[] public conversations;
    
    // Events
    event ConversationCreated(address indexed conversationAddress, address indexed creator);
    
    /**
     * @dev Creates a new Conversation contract
     * @param _title The title of the conversation
     * @param _description The description of the conversation
     * @return The address of the newly created conversation
     */
    function createConversation(
        string memory _title,
        string memory _description,
        address _authManager,
        uint256 _duration
    ) external returns (address) {
        // Deploy new Conversation contract
        Conversation newConversation = new Conversation(
            _title,
            _description,
            msg.sender,
            _duration,
            _authManager
        );
        
        // Store conversation data
        address conversationAddress = address(newConversation);
        conversations.push(conversationAddress);
        
        // Emit event
        emit ConversationCreated(conversationAddress, msg.sender);
        
        return conversationAddress;
    }
    
    /**
     * @dev Returns the number of conversations created
     * @return The total number of conversations
     */
    function getConversationCount() external view returns (uint256) {
        return conversations.length;
    }
    
    /**
     * @dev Returns all conversations created by a specific address
     * @param _creator The address of the creator
     * @return An array of conversation addresses
     */
    function getConversationsByCreator(address _creator) external view returns (address[] memory) {
        // First, count conversations by creator
        uint256 count = 0;
        for (uint256 i = 0; i < conversations.length; i++) {
            if (Conversation(conversations[i]).creator() == _creator) {
                count++;
            }
        }
        
        // Create array of correct size
        address[] memory creatorConversations = new address[](count);
        
        // Fill array with conversations
        uint256 index = 0;
        for (uint256 i = 0; i < conversations.length; i++) {
            if (Conversation(conversations[i]).creator() == _creator) {
                creatorConversations[index] = conversations[i];
                index++;
            }
        }
        
        return creatorConversations;
    }
}
