// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/ConversationFactory.sol";
import "../src/Conversation.sol";

contract DeployScript is Script {
    function run() external {
        // Get deployment private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy ConversationFactory
        ConversationFactory factory = new ConversationFactory();
        console.log("ConversationFactory deployed at:", address(factory));

        // Create a sample conversation
        address conversation = factory.createConversation(
            "First Conversation",
            "A test conversation",
            address(0), // No auth manager for this example
            7 days      // 1 week duration
        );
        console.log("Sample Conversation deployed at:", conversation);

        vm.stopBroadcast();

        // Log deployment summary
        console.log("\nDeployment Summary:");
        console.log("------------------------");
        console.log("Network:", block.chainid);
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        console.log("ConversationFactory:", address(factory));
        console.log("Sample Conversation:", conversation);
    }
}