// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "./AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ERC20BurnableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {MulticallUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";

/**
 * @title HKGXToken
 * @dev An upgradeable ERC20 token with role-based access control for minting and burning,
 *      and a configurable transaction fee, using UUPS for upgrades and Pausable for pausing.
 */
contract HKGXToken is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    OwnableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable,
    MulticallUpgradeable
{
    /// @dev Role for minting new tokens.
    bytes32 public constant MINT_ROLE = keccak256("MINT_ROLE");

    /// @dev Role for burning tokens.
    bytes32 public constant BURN_ROLE = keccak256("BURN_ROLE");

    /// @dev Role for controlling the transaction fee rate.
    bytes32 public constant FEE_CONTROLLER_ROLE = keccak256("FEE_CONTROLLER_ROLE");

    /// @dev Role for freezing and unfreezing accounts.
    bytes32 public constant FREEZE_ROLE = keccak256("FREEZE_ROLE");

    /// @dev Constants for fee exemption types.
    uint8 public constant FROM_EXEMPTION = 0;

    uint8 public constant TO_EXEMPTION = 1;

    /// @dev The maximum allowed fee rate (10000 basis points = 100%).
    uint256 public constant MAX_FEE_RATE = 10000;

    // keccak256(abi.encode(uint256(keccak256("eth.storage.HKGXToken")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant HKGX_TOKEN_STORAGE_LOCATION =
        0x350d25ba716126c86382f0281e374d8443ed74b03f46f6a8b5beeb927b77f400;

    /// @custom:storage-location erc7201:eth.storage.HKGXToken
    struct HKGXTokenStorage {
        /// @dev Mapping to track frozen accounts
        mapping(address => bool) frozenAccounts;
        /// @dev The transaction fee rate, in basis points. 1% is 100. Max is 10000.
        uint256 feeRate;
        /// @dev The address that receives transaction fees.
        address feeAddress;
        /**
         * @dev Fee exemption mapping: account => (0: from exemption, 1: to exemption) => bool
         * If an account has from exemption, it doesn't pay fees when sending tokens.
         * If an account has to exemption, it doesn't trigger fees when receiving tokens.
         */
        mapping(address => mapping(uint8 => bool)) feeExemptions;
        /// @dev The number of decimals for the token.
        uint8 decimals_;
        /// @dev crosschain CCIP
        address ccipAdmin;
    }

    function _getHKGXTokenStorage() internal pure returns (HKGXTokenStorage storage $) {
        assembly {
            $.slot := HKGX_TOKEN_STORAGE_LOCATION
        }
    }

    /**
     * @dev Emitted when the fee rate is changed.
     * @param previousFeeRate The previous fee rate.
     * @param newFeeRate The new fee rate.
     * @param setter The address that changed the fee rate.
     */
    event FeeRateChanged(uint256 previousFeeRate, uint256 newFeeRate, address indexed setter);

    /**
     * @dev Emitted when the fee address is changed.
     * @param previousFeeAddress The previous fee address.
     * @param newFeeAddress The new fee address.
     * @param setter The address that changed the fee address.
     */
    event FeeAddressChanged(address indexed previousFeeAddress, address indexed newFeeAddress, address indexed setter);

    /**
     * @dev Emitted when the CCIP admin address is changed.
     * @param previousAddress The previous CCIP admin address.
     * @param newAddress The new CCIP admin address.
     */
    event CCIPAdminChanged(address indexed previousAddress, address indexed newAddress);

    /**
     * @dev Emitted when an account is frozen.
     * @param account The address of the frozen account.
     * @param freezer The address that froze the account.
     */
    event AccountFrozen(address indexed account, address indexed freezer);

    /**
     * @dev Emitted when an account is unfrozen.
     * @param account The address of the unfrozen account.
     * @param unfreezer The address that unfroze the account.
     */
    event AccountUnfrozen(address indexed account, address indexed unfreezer);

    /**
     * @dev Emitted when tokens are force burned from a frozen account.
     * @param account The account from which tokens were force burned.
     * @param amount The amount of tokens burned.
     * @param burner The address that performed the force burn.
     */
    event ForceBurn(address indexed account, uint256 amount, address indexed burner);

    /**
     * @dev Emitted when fee exemption status is changed for an account.
     * @param account The account whose exemption status changed.
     * @param exemptionType The type of exemption (0: from, 1: to).
     * @param isExempt Whether the account is now exempt.
     * @param setter The address that changed the exemption status.
     */
    event FeeExemptionChanged(address indexed account, uint8 exemptionType, bool isExempt, address indexed setter);

    /**
     * @dev Emitted when the provided fee rate exceeds the maximum allowed fee rate.
     * @param feeRate The fee rate that was attempted to be set.
     * @param maxFeeRate The maximum allowed fee rate.
     */
    error FeeRateTooHigh(uint256 feeRate, uint256 maxFeeRate);

    /**
     * @dev Emitted when an operation is attempted on a frozen account.
     * @param account The address of the frozen account.
     */
    error ERC20FrozenAccount(address account);

    /**
     * @dev Emitted when an operation is attempted on an account that is not frozen.
     * @param account The address of the account that is not frozen.
     */
    error AccountNotFrozen(address account);

    /// @dev Emitted when an invalid fee address is provided (zero address).
    error InvalidFeeAddress();

    /// @dev Emitted when an invalid exemption type is provided.
    error InvalidExemptionType();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the contract.
     * @param name The name of the token.
     * @param symbol The symbol of the token.
     * @param decimals_ The number of decimals for the token.
     * @param initialOwner The initial owner of the contract.
     * @param initialFeeRate The initial fee rate in basis points.
     * @param initialFeeAddress The initial address to receive fees.
     */
    function initialize(
        string memory name,
        string memory symbol,
        uint8 decimals_,
        address initialOwner,
        uint256 initialFeeRate,
        address initialFeeAddress
    ) public initializer {
        if (initialFeeAddress == address(0)) {
            revert InvalidFeeAddress();
        }
        if (initialFeeRate > MAX_FEE_RATE) {
            revert FeeRateTooHigh(initialFeeRate, MAX_FEE_RATE);
        }

        __ERC20_init(name, symbol);
        __ERC20Burnable_init();
        __Ownable_init(initialOwner);
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __Pausable_init();
        __Multicall_init();

        HKGXTokenStorage storage $ = _getHKGXTokenStorage();
        $.feeRate = initialFeeRate;
        $.feeAddress = initialFeeAddress;
        $.decimals_ = decimals_;
        $.ccipAdmin = initialOwner;
    }

    /**
     * @dev See {UUPSUpgradeable-_authorizeUpgrade}.
     * @dev Only owner can authorize upgrades.
     */
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {}

    /// @dev See {AccessControlUpgradeable-_isOwner}.
    function _isOwner(address account) internal view override returns (bool) {
        return owner() == account;
    }

    /**
     * @dev Returns the number of decimals for the token.
     * @return The number of decimals.
     */
    function decimals() public view override returns (uint8) {
        HKGXTokenStorage storage $ = _getHKGXTokenStorage();
        return $.decimals_;
    }

    /**
     * @dev Pauses the contract. only owner can pause.
     */
    function pause() public virtual onlyOwner {
        _pause();
    }

    /**
     * @dev Unpauses the contract. only owner can unpause.
     */
    function unpause() public virtual onlyOwner {
        _unpause();
    }

    /**
     * @dev Mints new tokens.
     * @param to The address to mint tokens to.
     * @param amount The amount of tokens to mint.
     * @notice Requires MINT_ROLE.
     */
    function mint(address to, uint256 amount) public virtual onlyRole(MINT_ROLE) whenNotPaused {
        _mint(to, amount);
    }

    /**
     * @dev Burns tokens from a specific account with approval.
     * @param account The account to burn tokens from.
     * @param amount The amount of tokens to burn.
     * @notice Requires BURN_ROLE and the account must have approved the caller for at least the burn amount.
     */
    function burnFrom(address account, uint256 amount) public virtual override onlyRole(BURN_ROLE) whenNotPaused {
        super.burnFrom(account, amount);
    }

    /**
     * @dev Returns the current fee rate.
     * @return The fee rate in basis points.
     */
    function getFeeRate() public view returns (uint256) {
        HKGXTokenStorage storage $ = _getHKGXTokenStorage();
        return $.feeRate;
    }

    /**
     * @dev Returns the current fee address.
     * @return The address that receives transaction fees.
     */
    function getFeeAddress() public view returns (address) {
        HKGXTokenStorage storage $ = _getHKGXTokenStorage();
        return $.feeAddress;
    }

    /**
     * @dev Sets the transaction fee rate.
     * @param new_fee_rate The new fee rate in basis points.
     * @notice Requires FEE_CONTROLLER_ROLE.
     */
    function setFeeRate(uint256 new_fee_rate) public virtual onlyRole(FEE_CONTROLLER_ROLE) whenNotPaused {
        if (new_fee_rate > MAX_FEE_RATE) {
            revert FeeRateTooHigh(new_fee_rate, MAX_FEE_RATE);
        }
        HKGXTokenStorage storage $ = _getHKGXTokenStorage();
        uint256 previousFeeRate = $.feeRate;
        $.feeRate = new_fee_rate;
        emit FeeRateChanged(previousFeeRate, new_fee_rate, _msgSender());
    }

    /**
     * @dev Sets the fee address.
     * @param newFeeAddress The new address to receive fees.
     * @notice Only owner can change the fee address.
     */
    function setFeeAddress(address newFeeAddress) public virtual onlyOwner whenNotPaused {
        if (newFeeAddress == address(0)) {
            revert InvalidFeeAddress();
        }
        HKGXTokenStorage storage $ = _getHKGXTokenStorage();
        address previousFeeAddress = $.feeAddress;
        $.feeAddress = newFeeAddress;
        emit FeeAddressChanged(previousFeeAddress, newFeeAddress, _msgSender());
    }

    /**
     * @dev Forcefully burns tokens from any account.
     * @param account The account to burn tokens from.
     * @param amount The amount of tokens to burn.
     * @notice Requires BURN_ROLE. This can be used to burn tokens from blacklisted accounts.
     */
    function forceBurn(address account, uint256 amount) public virtual onlyRole(BURN_ROLE) whenNotPaused {
        HKGXTokenStorage storage $ = _getHKGXTokenStorage();
        if (!$.frozenAccounts[account]) {
            revert AccountNotFrozen(account);
        }
        _burn(account, amount);
        emit ForceBurn(account, amount, _msgSender());
    }

    /**
     * @dev Freezes an account, preventing transfers from it.
     * @param account The address of the account to freeze.
     * @notice Requires FREEZE_ROLE.
     */
    function freezeAccount(address account) public virtual onlyRole(FREEZE_ROLE) whenNotPaused {
        HKGXTokenStorage storage $ = _getHKGXTokenStorage();
        $.frozenAccounts[account] = true;
        emit AccountFrozen(account, _msgSender());
    }

    /**
     * @dev Unfreezes an account, allowing transfers from it.
     * @param account The address of the account to unfreeze.
     * @notice Requires FREEZE_ROLE.
     */
    function unfreezeAccount(address account) public virtual onlyRole(FREEZE_ROLE) whenNotPaused {
        HKGXTokenStorage storage $ = _getHKGXTokenStorage();
        $.frozenAccounts[account] = false;
        emit AccountUnfrozen(account, _msgSender());
    }

    /**
     * @dev Checks if an account is frozen.
     * @param account The account to check.
     * @return Whether the account is frozen.
     */
    function isFrozen(address account) public view returns (bool) {
        HKGXTokenStorage storage $ = _getHKGXTokenStorage();
        return $.frozenAccounts[account];
    }

    /**
     * @dev Sets fee exemption for an account.
     * @param account The account to set exemption for.
     * @param exemptionType The type of exemption (0: from, 1: to).
     * @param isExempt Whether the account should be exempt.
     * @notice Requires FEE_CONTROLLER_ROLE.
     */
    function setFeeExemption(address account, uint8 exemptionType, bool isExempt)
        public
        virtual
        onlyRole(FEE_CONTROLLER_ROLE)
        whenNotPaused
    {
        if (exemptionType != FROM_EXEMPTION && exemptionType != TO_EXEMPTION) {
            revert InvalidExemptionType();
        }
        HKGXTokenStorage storage $ = _getHKGXTokenStorage();
        $.feeExemptions[account][exemptionType] = isExempt;
        emit FeeExemptionChanged(account, exemptionType, isExempt, _msgSender());
    }

    /**
     * @dev Checks if an account has fee exemption.
     * @param account The account to check.
     * @param exemptionType The type of exemption to check.
     * @return Whether the account has the specified exemption.
     */
    function hasFeeExemption(address account, uint8 exemptionType) public view returns (bool) {
        HKGXTokenStorage storage $ = _getHKGXTokenStorage();
        return $.feeExemptions[account][exemptionType];
    }

    /**
     * @dev See {ERC20-_update}.
     * @dev Overridden to check for frozen accounts.
     */
    function _update(address from, address to, uint256 value) internal virtual override whenNotPaused {
        HKGXTokenStorage storage $ = _getHKGXTokenStorage();
        if (to != address(0)) {
            if ($.frozenAccounts[from]) {
                revert ERC20FrozenAccount(from);
            }
            if ($.frozenAccounts[to]) {
                revert ERC20FrozenAccount(to);
            }
        }
        super._update(from, to, value);
    }

    /**
     * @dev See {ERC20-transfer}.
     * @dev Overridden to apply transaction fees.
     */
    function transfer(address to, uint256 amount) public virtual override whenNotPaused returns (bool) {
        HKGXTokenStorage storage $ = _getHKGXTokenStorage();
        address sender = _msgSender();
        (uint256 actualAmount, uint256 fee) = _calculateTransferAmounts(sender, to, amount);
        if (fee > 0) {
            super.transfer($.feeAddress, fee);
        }
        return super.transfer(to, actualAmount);
    }

    /**
     * @dev See {ERC20-transferFrom}.
     * @dev Overridden to apply transaction fees.
     */
    function transferFrom(address from, address to, uint256 amount)
        public
        virtual
        override
        whenNotPaused
        returns (bool)
    {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);

        (uint256 actualAmount, uint256 fee) = _calculateTransferAmounts(from, to, amount);
        if (fee > 0) {
            super._transfer(from, getFeeAddress(), fee);
        }
        super._transfer(from, to, actualAmount);
        return true;
    }

    /**
     * @dev Sets the CCIP admin address.
     * @param newAdmin The new CCIP admin address to be set.
     * @notice Only owner can change the CCIP admin address.
     */
    function setCCIPAdmin(address newAdmin) public onlyOwner {
        HKGXTokenStorage storage $ = _getHKGXTokenStorage();
        address previous = $.ccipAdmin;
        $.ccipAdmin = newAdmin;
        emit CCIPAdminChanged(previous, newAdmin);
    }

    /**
     * @dev Returns the current CCIP admin address.
     * @return The address of the current CCIP admin.
     */
    function getCCIPAdmin() external view returns (address) {
        HKGXTokenStorage storage $ = _getHKGXTokenStorage();
        return $.ccipAdmin;
    }

    /**
     * @dev Calculates the actual transfer amount and fee.
     * @param from The address sending tokens.
     * @param to The address receiving tokens.
     * @param amount The total amount to transfer.
     * @return actualAmount The amount to transfer to the recipient after fee.
     * @return fee The fee amount to transfer to the owner.
     */
    function _calculateTransferAmounts(address from, address to, uint256 amount)
        internal
        view
        returns (uint256 actualAmount, uint256 fee)
    {
        HKGXTokenStorage storage $ = _getHKGXTokenStorage();
        uint256 feeRate = $.feeRate;
        // Check if fee should be applied
        bool shouldApplyFee = feeRate > 0 && to != $.feeAddress && !$.feeExemptions[from][FROM_EXEMPTION]
            && !$.feeExemptions[to][TO_EXEMPTION];
        if (shouldApplyFee) {
            fee = (amount * feeRate) / MAX_FEE_RATE;
            actualAmount = amount - fee;
        } else {
            actualAmount = amount;
        }
    }

    function _msgSender() internal view override(AccessControlUpgradeable, ContextUpgradeable) returns (address) {
        return msg.sender;
    }
}
