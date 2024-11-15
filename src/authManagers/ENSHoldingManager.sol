// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IAuthManager.sol";

interface IReverseRegistrar {
    function node(address addr) external pure returns (bytes32);
    function defaultResolver() external view returns (INameResolver);
}

interface INameResolver {
    function name(bytes32 node) external view returns (string memory);
}

contract ENSHoldingManager is IAuthManager {
    IReverseRegistrar public immutable reverseRegistrar;
    
    // Mainnet ENS Reverse Registrar: 0x084b1c3C81545d370f3634392De611CaaBFf8148
    constructor(address _reverseRegistrar) {
        require(_reverseRegistrar != address(0), "Reverse registrar cannot be 0");
        reverseRegistrar = IReverseRegistrar(_reverseRegistrar);
    }

    /**
     * @dev Checks if an address has an ENS name set
     * @param user Address to check
     * @return bool True if the address has an ENS name
     */
    function isWhitelisted(address user) external view override returns (bool) {
        bytes32 node = reverseRegistrar.node(user);
        INameResolver resolver = reverseRegistrar.defaultResolver();
        
        string memory name = resolver.name(node);
        return bytes(name).length > 0;
    }
} 