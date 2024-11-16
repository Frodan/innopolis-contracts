// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IAuthManager.sol";

/**
 * @title ETHBalanceManager
 * @dev Auth manager that checks if users have a minimum ETH balance
 */
contract ETHBalanceManager is IAuthManager {
    uint256 public immutable minBalance;

    constructor(uint256 _minBalance) {
        require(_minBalance > 0, "Minimum balance must be greater than 0");
        minBalance = _minBalance;
    }

    /**
     * @dev Checks if an address has the minimum required ETH balance
     * @param user Address to check
     * @return bool True if the user has sufficient ETH balance
     */
    function isWhitelisted(address user) external view override returns (bool) {
        return user.balance >= minBalance;
    }
} 