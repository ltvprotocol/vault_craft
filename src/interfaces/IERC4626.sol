// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

/// @title ERC-20 Minimal Interface
interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function name() external view returns (string memory); // ERC-20 Metadata
    function symbol() external view returns (string memory); // ERC-20 Metadata
    function decimals() external view returns (uint8); // ERC-20 Metadata

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

/// @title ERC-4626: Tokenized Vault Standard (Interface)
/// @notice Shares are ERC-20 tokens representing claims on a single underlying EIP-20 asset.
/// @dev Conforms to EIP-4626. Vaults MUST also implement ERC-20 (+ metadata) for shares.
///      Notes on rounding from the spec:
///        - convertTo* MUST round down.
///        - previewDeposit/previewMint/previewWithdraw/previewRedeem MUST be as-close-as-possible
///          to the exact result under current on-chain conditions and include fees for that action.
///      Limits (max*) MUST reflect global/user limits and MUST NOT revert.
///      preview* MUST ignore limits but MAY revert for the same reasons the action would revert.
interface IERC4626 is IERC20 {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when `sender` deposits `assets` and receives `shares` for `owner`.
    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);

    /// @notice Emitted when `sender` withdraws `assets` for `receiver` by redeeming `shares` from `owner`.
    event Withdraw(
        address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    /*//////////////////////////////////////////////////////////////
                             VAULT METADATA
    //////////////////////////////////////////////////////////////*/

    /// @notice The address of the underlying ERC-20 asset used by the vault for accounting.
    /// @return assetTokenAddress The underlying asset token.
    function asset() external view returns (address assetTokenAddress);

    /*//////////////////////////////////////////////////////////////
                           CONVERSION & ACCOUNTING
    //////////////////////////////////////////////////////////////*/

    /// @notice Total amount of the underlying `asset` managed by the vault.
    /// @dev SHOULD include accrued yield and be inclusive of any fees taken against assets.
    function totalAssets() external view returns (uint256 totalManagedAssets);

    /// @notice Convert an `assets` amount to the corresponding number of `shares` (rounding down).
    /// @dev Idealized (no fees/slippage; not caller-dependent). MUST NOT revert except on overflow.
    function convertToShares(uint256 assets) external view returns (uint256 shares);

    /// @notice Convert a `shares` amount to the corresponding number of `assets` (rounding down).
    /// @dev Idealized (no fees/slippage; not caller-dependent). MUST NOT revert except on overflow.
    function convertToAssets(uint256 shares) external view returns (uint256 assets);

    /*//////////////////////////////////////////////////////////////
                            DEPOSIT / MINT
    //////////////////////////////////////////////////////////////*/

    /// @notice Maximum `assets` that `receiver` can deposit via {deposit} without reverting.
    /// @dev MUST account for global/user limits. Return type: 2**256-1 if unlimited.
    function maxDeposit(address receiver) external view returns (uint256 maxAssets);

    /// @notice Preview how many `shares` would be minted by depositing `assets` right now.
    /// @dev MUST include deposit fees. Ignores limits/allowances. See spec for rounding.
    function previewDeposit(uint256 assets) external view returns (uint256 shares);

    /// @notice Deposit exactly `assets`, minting `shares` to `receiver`.
    /// @dev MUST emit {Deposit}. MUST support ERC-20 approve/transferFrom of `asset`.
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    /// @notice Maximum `shares` that can be minted to `receiver` via {mint} without reverting.
    /// @dev MUST account for global/user limits. Return type: 2**256-1 if unlimited.
    function maxMint(address receiver) external view returns (uint256 maxShares);

    /// @notice Preview how many `assets` would be required to mint `shares` right now.
    /// @dev MUST include deposit fees. Ignores limits/allowances. See spec for rounding.
    function previewMint(uint256 shares) external view returns (uint256 assets);

    /// @notice Mint exactly `shares` to `receiver`, pulling the required `assets`.
    /// @dev MUST emit {Deposit}. MUST support ERC-20 approve/transferFrom of `asset`.
    function mint(uint256 shares, address receiver) external returns (uint256 assets);

    /*//////////////////////////////////////////////////////////////
                           WITHDRAW / REDEEM
    //////////////////////////////////////////////////////////////*/

    /// @notice Maximum `assets` that can be withdrawn for `owner` via {withdraw} without reverting.
    /// @dev MUST account for global/user limits. MUST NOT revert.
    function maxWithdraw(address owner) external view returns (uint256 maxAssets);

    /// @notice Preview how many `shares` would be redeemed to withdraw `assets` right now.
    /// @dev MUST include withdrawal fees. Ignores limits/allowances. See spec for rounding.
    function previewWithdraw(uint256 assets) external view returns (uint256 shares);

    /// @notice Withdraw exactly `assets` to `receiver`, redeeming `shares` from `owner`.
    /// @dev MUST emit {Withdraw}. MUST check allowance when `msg.sender` != `owner`.
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);

    /// @notice Maximum `shares` that can be redeemed for `owner` via {redeem} without reverting.
    /// @dev MUST account for global/user limits. MUST NOT revert.
    function maxRedeem(address owner) external view returns (uint256 maxShares);

    /// @notice Preview how many `assets` would be received by redeeming `shares` right now.
    /// @dev MUST include withdrawal fees. Ignores limits/allowances. See spec for rounding.
    function previewRedeem(uint256 shares) external view returns (uint256 assets);

    /// @notice Redeem exactly `shares` from `owner`, sending `assets` to `receiver`.
    /// @dev MUST emit {Withdraw}. MUST check allowance when `msg.sender` != `owner`.
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
}
