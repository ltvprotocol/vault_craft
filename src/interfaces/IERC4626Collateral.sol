// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

interface IERC4626Collateral {
    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);

    event Withdraw(
        address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    function maxDepositCollateral(address receiver) external view returns (uint256 maxAssets);

    function previewDepositCollateral(uint256 assets) external view returns (uint256 shares);

    function depositCollateral(uint256 assets, address receiver) external returns (uint256 shares);

    function maxMintCollateral(address receiver) external view returns (uint256 maxShares);

    function previewMintCollateral(uint256 shares) external view returns (uint256 assets);

    function mintCollateral(uint256 shares, address receiver) external returns (uint256 assets);

    function maxWithdrawCollateral(address owner) external view returns (uint256 maxAssets);

    function previewWithdrawCollateral(uint256 assets) external view returns (uint256 shares);

    function withdrawCollateral(uint256 assets, address receiver, address owner) external returns (uint256 shares);

    function maxRedeemCollateral(address owner) external view returns (uint256 maxShares);

    function previewRedeemCollateral(uint256 shares) external view returns (uint256 assets);

    function redeemCollateral(uint256 shares, address receiver, address owner) external returns (uint256 assets);
}
