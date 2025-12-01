# HKGX Token - Gold-Backed Digital Asset

## 🌟 Overview

HKGX Token is a secure, transparent, and feature-rich ERC20 token designed to represent gold-backed digital assets on the blockchain. Built with enterprise-grade security standards and comprehensive access controls, HKGX Token provides a trusted bridge between physical gold assets and the digital economy.

## ✨ Key Features

### 🔒 **Enterprise Security**
- **Upgradeable Architecture**: Built on OpenZeppelin's battle-tested upgradeable contracts using the UUPS (Universal Upgradeable Proxy Standard) pattern
- **Pausable Contract**: Emergency pause functionality to protect users in case of critical issues
- **Role-Based Access Control**: Granular permission system ensuring only authorized parties can perform sensitive operations
- **Account Freezing**: Compliance and security feature to freeze accounts when necessary (e.g., regulatory requirements, suspicious activity)

### 💰 **Transparent Fee System**
- **Configurable Transaction Fees**: Transparent fee structure with publicly viewable fee rates
- **Fee Exemptions**: Flexible exemption system for specific accounts (sender or receiver exemptions)
- **Maximum Fee Protection**: Hard-coded maximum fee rate cap (100%) to prevent excessive fees
- **Public Fee Tracking**: All fee changes are emitted as on-chain events for full transparency

### 🌐 **Cross-Chain Capabilities**
- **CCIP Integration**: Built-in support for Chainlink's Cross-Chain Interoperability Protocol (CCIP), enabling seamless cross-chain transfers
- **Multi-Chain Ready**: Designed to work across multiple blockchain networks

### 🔍 **Full Transparency**
- **On-Chain Events**: All critical operations emit events that can be tracked on-chain
- **Public View Functions**: All important parameters (fee rate, fee address, frozen status) are publicly viewable
- **Open Source**: MIT licensed codebase built on industry-standard OpenZeppelin libraries

### ⚡ **Advanced Functionality**
- **Burnable Tokens**: Tokens can be burned by authorized parties, maintaining supply integrity
- **Multicall Support**: Batch multiple operations in a single transaction for efficiency
- **Custom Decimals**: Configurable decimal precision for different use cases

## 🛡️ Security & Trust Features

### Role-Based Access Control

The token implements a sophisticated role-based access control system with the following roles:

- **MINT_ROLE**: Authorized to mint new tokens (typically reserved for gold custodians)
- **BURN_ROLE**: Authorized to burn tokens (for redemption or supply management)
- **FEE_CONTROLLER_ROLE**: Manages transaction fee rates
- **FREEZE_ROLE**: Can freeze/unfreeze accounts for compliance purposes
- **Owner**: Ultimate control over critical parameters (fee address, CCIP admin, upgrades)

### Account Freezing Mechanism

For regulatory compliance and security:
- Accounts can be frozen to prevent transfers
- Only accounts with `FREEZE_ROLE` can freeze/unfreeze accounts
- Frozen accounts cannot send or receive tokens
- All freeze/unfreeze actions are logged as on-chain events
- Force burn capability for frozen accounts (with proper authorization)

### Upgrade Safety

- Only the contract owner can authorize upgrades
- Uses UUPS pattern for secure, controlled upgrades
- Initializer pattern prevents re-initialization attacks

## 💸 Fee System Explained

### How Fees Work

1. **Fee Calculation**: Fees are calculated as a percentage of the transfer amount (in basis points)
   - Example: 1% fee = 100 basis points
   - Maximum fee rate is capped at 100% (10,000 basis points)

2. **Fee Exemptions**:
   - **FROM_EXEMPTION**: Account doesn't pay fees when sending tokens
   - **TO_EXEMPTION**: Account doesn't trigger fees when receiving tokens
   - Fee address is automatically exempt from fees

3. **Transparency**:
   - Current fee rate: `getFeeRate()` - viewable by anyone
   - Fee recipient: `getFeeAddress()` - publicly viewable
   - All fee changes emit `FeeRateChanged` events
   - Fee exemption status: `hasFeeExemption()` - checkable for any account

### Fee Events

All fee-related changes are transparently logged:
- `FeeRateChanged`: When fee rate is updated
- `FeeAddressChanged`: When fee recipient address changes
- `FeeExemptionChanged`: When exemption status changes for any account

## 📊 Transparency & Auditability

### Public View Functions

Anyone can verify the token's state:
- `getFeeRate()`: Current transaction fee rate
- `getFeeAddress()`: Address receiving fees
- `isFrozen(address)`: Check if an account is frozen
- `hasFeeExemption(address, exemptionType)`: Check exemption status
- `getCCIPAdmin()`: Current CCIP admin address
- `decimals()`: Token decimal precision

### On-Chain Events

All critical operations emit events for full auditability:
- `FeeRateChanged`: Fee rate updates
- `FeeAddressChanged`: Fee address changes
- `AccountFrozen` / `AccountUnfrozen`: Account freeze status changes
- `ForceBurn`: Tokens burned from frozen accounts
- `FeeExemptionChanged`: Exemption status changes
- `CCIPAdminChanged`: Cross-chain admin changes

## 🔧 Technical Specifications

### Standards Compliance
- **ERC20**: Full ERC20 token standard compliance
- **ERC20Burnable**: Burnable token extension
- **ERC7201**: Namespaced storage layout for upgrade safety

### Smart Contract Libraries
- OpenZeppelin Contracts Upgradeable v0.8.22+
- Battle-tested, audited codebase

### Key Parameters
- **Maximum Fee Rate**: 10,000 basis points (100%)
- **Upgrade Pattern**: UUPS (Universal Upgradeable Proxy Standard)
- **Storage Layout**: ERC7201 namespaced storage for upgrade safety

## 🚀 Use Cases

- **Gold Tokenization**: Represent physical gold holdings as digital tokens
- **Cross-Chain Gold Trading**: Transfer gold-backed tokens across blockchain networks
- **Institutional Compliance**: Built-in freezing and role management for regulatory compliance
- **Transparent Fee Structure**: Clear, viewable fee system for institutional users
- **Supply Management**: Controlled minting and burning for maintaining gold backing

## 🔐 Trust Indicators

1. **Open Source**: MIT licensed, fully auditable code
2. **Industry Standards**: Built on OpenZeppelin's audited contracts
3. **Transparent Operations**: All critical changes are on-chain events
4. **Role Separation**: Different roles for different functions (no single point of control)
5. **Upgrade Control**: Only owner can upgrade, preventing unauthorized changes
6. **Maximum Fee Protection**: Hard-coded limits prevent excessive fees
7. **Emergency Controls**: Pause functionality for critical situations

## 📝 Important Notes

- The contract is **pausable** - operations may be temporarily paused by the owner in emergencies
- Accounts can be **frozen** for compliance reasons - check account status before large transfers
- **Fees apply** to transfers unless exemptions are granted - verify fee rates before transacting
- The contract is **upgradeable** - upgrades are controlled by the owner and logged on-chain
- **Cross-chain transfers** require CCIP integration - verify CCIP admin configuration

## 🔗 Contract Information

- **License**: MIT
- **Solidity Version**: ^0.8.22
- **Proxy Pattern**: UUPS (Universal Upgradeable Proxy Standard)
- **Storage Pattern**: ERC7201 Namespaced Storage

## 📞 Support & Verification

To verify the contract's current state:
1. Check fee rate: Call `getFeeRate()` on the contract
2. Verify fee address: Call `getFeeAddress()` on the contract
3. Check account status: Call `isFrozen(address)` for any account
4. Review on-chain events: All changes are logged as events

---

**Disclaimer**: This token represents a gold-backed digital asset. Users should verify the gold backing, custodial arrangements, and regulatory compliance before use. Always conduct your own research and due diligence.

