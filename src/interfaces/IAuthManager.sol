// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IAuthManager
 * @dev Manages whitelisting
 */
interface IAuthManager {
    function isWhitelisted(address _user) external view returns (bool);
}