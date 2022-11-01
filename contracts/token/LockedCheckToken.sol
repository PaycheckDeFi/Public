//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC20PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";

import {IERC20Mintable} from "./IERC20Mintable.sol";

contract LockedCheckToken is IERC20Mintable, OwnableUpgradeable, AccessControlUpgradeable, ERC20PausableUpgradeable {
    // Role to be able to mint tokens (Locker contract)
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Token decimals
    uint8 private constant DECIMALS = 6;

    // Whitelist for transfers
    mapping(address => bool) private _whitelist;

    /// Transfer not allowed for addresses other than whitelisted
    error TransferDenied();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @param name_ name of the token
     * @param symbol_ the symbol name of the token (ticker symbol)
     */
    function initialize(string memory name_, string memory symbol_) external initializer {
        __ERC20_init(name_, symbol_);
        __Ownable_init_unchained();
        __AccessControl_init_unchained();
        __ERC20Pausable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());
    }

    /**
     * @dev checks if `account` is the member of the whitelist
     * @param account account to be checked
     * @return if the account is the member of the whitelist
     */
    function isMember(address account) public view returns (bool) {
        return _whitelist[account];
    }

    /**
     * @dev Adds the address `account` is the member of the whitelist
     * @param account address to be added
     */
    function addMember(address account) external onlyOwner {
        _whitelist[account] = true;
    }

    /**
     * @dev Removes the address `account` from the whitelist
     * @param account address to be removed
     */
    function removeMember(address account) external onlyOwner {
        delete _whitelist[account];
    }

    /**
     * @dev Returns the number of decimals used to get LCHECK user representation.
     */
    function decimals() public view virtual override returns (uint8) {
        return DECIMALS;
    }

    /**
     * @dev Mints `amount` tokens to the `account` address.
     *
     * See {ERC20-_burn}.
     */
    function mint(address account, uint256 amount) external override onlyRole(MINTER_ROLE) {
        _mint(account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from the caller.
     */
    function burn(address account, uint256 amount) external override onlyRole(MINTER_ROLE) {
        _burn(account, amount);
    }

    /**
     * @dev Validates if it is allowed to transfer the token
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 /*amount*/
    ) internal virtual override {
        // deny transfer if it's a normal transfer (not mint / burn) and from and to not in whitelist
        if (from != address(0) && to != address(0) && !isMember(from) && !isMember(to)) revert TransferDenied();
    }
}
