// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/Multicall.sol";
import "../interfaces/IAuthManager.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title TokenHoldingManager
 * @dev Manages whitelisting based on token holding
 */
contract TokenHoldingManager is IAuthManager {
    // State variables
    address public token;
    uint256 public minBalance;

    constructor(address _token, uint256 _minBalance) {
        require(_token != address(0), "Token address cannot be 0");
        token = _token;
        minBalance = _minBalance;
    }

    function isWhitelisted(address _user) external view returns (bool) {
        return IERC20(token).balanceOf(_user) >= minBalance;
    }
}
