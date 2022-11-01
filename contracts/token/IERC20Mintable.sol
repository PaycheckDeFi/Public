// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @dev Interface for the mint and burn operations of the ERC20 tokens
 */
interface IERC20Mintable {
    /**
     * @dev mint `amount` of tokens to `account` address
     */
    function mint(address account, uint256 amount) external;

    /**
     * @dev burn `amount` of tokens from `account` address
     */
    function burn(address account, uint256 amount) external;
}
