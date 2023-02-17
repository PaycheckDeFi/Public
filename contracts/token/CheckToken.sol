// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @notice CHECK token contract (upgradeable with Transparent Proxy pattern)
 *
 * @title The tax fee token (from each transaction the fee is taken:
 * 5% for each token holder according to the share
 * 3% to project development purpose)
 *
 * @dev implementetation is inspired by reflection tokens approach (SafeMoon, Reflect.Finance etc)
 */
contract CheckToken is ERC20Upgradeable, OwnableUpgradeable {
    /**
     * @notice Include in rewards event
     * @dev Emitted when `account`is included for getting rewards
     * @param account address of the account
     */
    event IncludeInReward(address account);

    /**
     * @notice Exclude from rewards event
     * @dev Emitted when `account`is excluded from getting rewards
     * @param account address of the account
     */
    event ExcludeFromReward(address account);

    /**
     * @notice Include in fee event
     * @dev Emitted when `account`is included for tax fee
     * @param account address of the account
     */
    event IncludeInFee(address account);

    /**
     * @notice Exclude from fee event
     * @dev Emitted when `account`is excluded from tax fee
     * @param account address of the account
     */
    event ExcludeFromFee(address account);

    /**
     * @notice Include in power status
     * @dev Emitted when `account`is included in power status
     * @param account address of the account
     */
    event IncludeInPowerStatus(address account);

    /**
     * @notice Exclude from power status
     * @dev Emitted when `account`is excluded from power status
     * @param account address of the account
     */
    event ExcludeFromPowerStatus(address account);

    /**
     * @notice Update fee event
     * @dev Emitted when the fee is updated
     */
    event UpdateFee(string indexed feeType, uint256 previousTaxFee, uint256 newTaxFee);

    /// Reflected balances in units according to transaction fees collected
    mapping(address => uint256) private _rOwned;

    /// Direct balances of the accounts
    mapping(address => uint256) private _tOwned;

    /// Address allowances
    mapping(address => mapping(address => uint256)) private _tokenAllowances;

    /// Mapping of exclusion addresses from taking fees
    mapping(address => bool) private _isExcludedFromFee;

    /// Mapping of exclusion addresses
    mapping(address => bool) private _isExcluded;

    /// The list of excluded adresses
    address[] private _excluded;

    /// Address of the LCHECK token
    ERC20Upgradeable private _lockToken;

    /// Number of decimals of the token
    uint8 public constant DECIMALS = 6;

    /// Maximum accepted value (for adjustement of precision)
    uint256 private constant MAX = 10**64;

    /// Total supply of the token
    uint256 private _tTotal;

    /// Reflected total supply
    uint256 private _rTotal;

    /// Current rate between reflected and direct amount of tokens (updated on each transfer)
    uint256 private currentRate;

    /// Total fees extracted
    uint256 private _tFeeTotal;

    /// Transfer fee percentage
    uint256 public _taxFee;
    uint256 private _previousTaxFee;

    /// Project fee percentage
    uint256 public _projectFee;
    uint256 private _previousProjectFee;

    /// Minimum amount of tokens for the holder to be excluded from taking fees
    uint256 private _graceTokenAmount;

    /// Project fee receiver
    address private _projectFeeReceiver;

    /// Mapping of exclusions of Power Users
    mapping(address => bool) private _isExcludedPowerStatus;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @param name_ name of the token
     * @param symbol_ the symbol name of the token (ticker symbol)
     * @param lockToken_ address of the LCHECK token
     * @param projectFeeReceiver address of the project fee receiever wallet
     */
    function initialize(
        string memory name_,
        string memory symbol_,
        address lockToken_,
        address projectFeeReceiver
    ) public initializer {
        __ERC20_init(name_, symbol_);
        __Ownable_init();

        require(projectFeeReceiver != address(0), "ERC20: no fees reciever");

        _isExcluded[owner()] = true;
        _isExcludedFromFee[owner()] = true;

        _isExcluded[address(this)] = true;
        _isExcludedFromFee[address(this)] = true;

        _isExcludedFromFee[projectFeeReceiver] = true;
        _isExcluded[projectFeeReceiver] = true;

        _tTotal = 100 * 10**9 * 10**DECIMALS;
        _rTotal = (MAX - (MAX % _tTotal));
        currentRate = _rTotal / _tTotal;

        _taxFee = 5;
        _projectFee = 3;
        _graceTokenAmount = 100_000_000 * (10**DECIMALS);

        _rOwned[_msgSender()] = _rTotal;
        _tOwned[_msgSender()] = _tTotal;

        _lockToken = ERC20Upgradeable(lockToken_);
        _projectFeeReceiver = projectFeeReceiver;

        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return _tokenFromReflection(_rOwned[account]);
    }

    function increaseAllowance(address spender, uint256 addedValue) public override returns (bool) {
        _approve(_msgSender(), spender, _tokenAllowances[_msgSender()][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public override returns (bool) {
        _approve(_msgSender(), spender, _tokenAllowances[_msgSender()][spender] - subtractedValue);
        return true;
    }

    function isExcludedFromReward(address account) external view returns (bool) {
        return _isExcluded[account];
    }

    function isExcludedPowerStatus(address account) public view returns (bool) {
        return _isExcludedPowerStatus[account];
    }

    function totalFees() external view returns (uint256) {
        return _tFeeTotal;
    }

    function tokenFromReflection(uint256 rAmount) external view returns (uint256) {
        return _tokenFromReflection(rAmount);
    }

    function excludeFromReward(address account) external onlyOwner {
        _excludeFromReward(account);
    }

    function includeInReward(address account) external onlyOwner {
        _includeInReward(account);
    }

    function excludeFromPowerStatus(address account) external onlyOwner {
        require(!_isExcludedPowerStatus[account], "Account is already excluded");
        _isExcludedPowerStatus[account] = true;
        emit ExcludeFromPowerStatus(account);
    }

    function includeInPowerStatus(address account) external onlyOwner {
        require(_isExcludedPowerStatus[account], "Account is not excluded");
        _isExcludedPowerStatus[account] = false;
        emit IncludeInPowerStatus(account);
    }

    function excludeFromFee(address account) external onlyOwner {
        require(!_isExcludedFromFee[account], "Account is already excluded");
        _isExcludedFromFee[account] = true;
        emit ExcludeFromFee(account);
    }

    function includeInFee(address account) external onlyOwner {
        require(_isExcludedFromFee[account], "Account is not excluded");
        _isExcludedFromFee[account] = false;
        emit IncludeInFee(account);
    }

    function isExcludedFromFee(address account) external view returns (bool) {
        return _isExcludedFromFee[account];
    }

    function decimals() public view virtual override returns (uint8) {
        return DECIMALS;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transferFrom(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address ownerAddress, address spender) public view override returns (uint256) {
        return _tokenAllowances[ownerAddress][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        uint256 currentAllowance = _tokenAllowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: exceeds allowance");
        _approve(sender, _msgSender(), currentAllowance - amount);
        _transferFrom(sender, recipient, amount);        

        return true;
    }

    function updateProjectFeeReceiver(address projectFeeReceiver) external onlyOwner {
        require(projectFeeReceiver != address(0), "ERC20: no fees reciever");
        _isExcludedFromFee[projectFeeReceiver] = true;
        _isExcluded[projectFeeReceiver] = true;
        _projectFeeReceiver = projectFeeReceiver;
    }

    function setTaxFee(uint256 taxFee) external onlyOwner {
        require(taxFee <= 20, "TaxFee exceeds 20");
        _taxFee = taxFee;
        emit UpdateFee("Tax", _taxFee, taxFee);
    }

    function setProjectFee(uint256 projectFee) external onlyOwner {
        require(projectFee <= 20, "LiquidityFee exceeds 20");
        _projectFee = projectFee;
        emit UpdateFee("Project", _projectFee, projectFee);
    }

    function reflectionFromToken(uint256 tAmount, bool deductFee) external view returns (uint256) {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductFee) {
            (uint256 rAmount, , , , , ) = _getValues(tAmount);
            return rAmount;
        } else {
            (, uint256 rTransferAmount, , , , ) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    function isExcludedFromFee(address from, address to) public view returns (bool) {
        uint256 totalFromBalance = _lockToken.balanceOf(from) + balanceOf(from);
        uint256 totalToBalance = _lockToken.balanceOf(to) + balanceOf(to);

        if (_isExcludedFromFee[from] || _isExcludedFromFee[to]) return true;

        return
            (_graceTokenAmount > 0) &&
            ((totalFromBalance >= _graceTokenAmount && !isExcludedPowerStatus(from)) ||
                (totalToBalance >= _graceTokenAmount && !isExcludedPowerStatus(to)));
    }

    function _tokenFromReflection(uint256 rAmount) internal view returns (uint256) {
        require(rAmount <= _rTotal, "Check: exceeds reflected total");
        return rAmount / currentRate;
    }

    function _approve(
        address ownerAddress,
        address spender,
        uint256 amount
    ) internal virtual override {
        require(ownerAddress != address(0), "ERC20: approve from 0 address");
        require(spender != address(0), "ERC20: approve to 0 address");

        _tokenAllowances[ownerAddress][spender] = amount;
        emit Approval(ownerAddress, spender, amount);
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal - rFee;
        _tFeeTotal = _tFeeTotal + tFee;
    }

    function _updateRate() private {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        currentRate = rSupply / tSupply;
    }

    function _excludeFromReward(address account) internal {
        require(!_isExcluded[account], "Account is already excluded");

        if (_rOwned[account] > 0) {
            _tOwned[account] = _tokenFromReflection(_rOwned[account]);
        }

        _isExcluded[account] = true;
        _excluded.push(account);

        emit ExcludeFromReward(account);
    }

    function _includeInReward(address account) internal {
        require(_isExcluded[account], "Account is not excluded");

        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _rOwned[account] = _tOwned[account] * currentRate;
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();

                emit IncludeInReward(account);
                break;
            }
        }
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;

        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply - _rOwned[_excluded[i]];
            tSupply = tSupply - _tOwned[_excluded[i]];
        }

        if (rSupply < _rTotal / _tTotal) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function _takeProjectFee(uint256 tProjectFee) private {
        uint256 rProjectFee = tProjectFee * currentRate;
        _rOwned[_projectFeeReceiver] = _rOwned[_projectFeeReceiver] + rProjectFee;

        if (_isExcluded[address(this)]) _tOwned[_projectFeeReceiver] = _tOwned[_projectFeeReceiver] + tProjectFee;
    }

    function _removeAllFee() private {
        if (_taxFee == 0 && _projectFee == 0) return;

        _previousTaxFee = _taxFee;
        _previousProjectFee = _projectFee;

        _taxFee = 0;
        _projectFee = 0;
    }

    function _restoreAllFee() private {
        _taxFee = _previousTaxFee;
        _projectFee = _previousProjectFee;
    }

    function _getValues(uint256 tAmount)
        internal
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        (uint256 tTransferAmount, uint256 tFee, uint256 tProjectFee) = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(tAmount, tFee, tProjectFee);
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee, tProjectFee);
    }

    function _getTValues(uint256 tAmount)
        internal
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 tFee = _calculateTaxFee(tAmount);
        uint256 tProjectFee = _calculateProjectFee(tAmount);
        uint256 tTransferAmount = tAmount - tFee - tProjectFee;
        return (tTransferAmount, tFee, tProjectFee);
    }

    function _getRValues(
        uint256 tAmount,
        uint256 tFee,
        uint256 tProjectFee
    )
        internal
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 rAmount = tAmount * currentRate;
        uint256 rFee = tFee * currentRate;
        uint256 rProjectFee = tProjectFee * currentRate;
        uint256 rTransferAmount = rAmount - rFee - rProjectFee;
        return (rAmount, rTransferAmount, rFee);
    }

    function _calculateTaxFee(uint256 _amount) private view returns (uint256) {
        return (_amount * _taxFee) / 10**2;
    }

    function _calculateProjectFee(uint256 _amount) private view returns (uint256) {
        return (_amount * _projectFee) / 10**2;
    }

    function _transferFrom(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: zero from address");
        require(to != address(0), "ERC20: zero to address");
        require(amount > 0, "Zero transfer amount");

        bool noFee = isExcludedFromFee(from, to);
        if (noFee) _removeAllFee();

        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tProjectFee
        ) = _getValues(amount);

        require(_rOwned[from] >= rAmount, "ERC20: transfer exceeds balance");

        // Adjust reflected unit amount
        _rOwned[from] -= rAmount;
        _rOwned[to] += rTransferAmount;

        // if sender exluded then subtract from the direct balance
        if (_isExcluded[from]) {
            _tOwned[from] -= amount;
        }

        // if receiever exluded then add to the direct balance
        if (_isExcluded[to]) {
            _tOwned[to] += amount;
        }

        _takeProjectFee(tProjectFee);
        _reflectFee(rFee, tFee);

        // ajust the current rate
        _updateRate();

        emit Transfer(from, to, tTransferAmount);

        if (noFee) _restoreAllFee();
    }
}
