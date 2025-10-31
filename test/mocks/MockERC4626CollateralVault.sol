// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC4626Collateral} from "../../src/interfaces/IERC4626Collateral.sol";

contract MockERC4626CollateralVault is IERC4626Collateral {
    address public assetCollateral;
    uint256 public totalAssetsAmount;
    uint256 public totalSharesAmount;
    uint256 public exchangeRate = 1e18; // 1:1 by default
    bool public shouldRevert;
    string public revertReason;

    mapping(address => uint256) public balanceOf;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function setExchangeRate(uint256 _rate) external {
        exchangeRate = _rate;
    }

    function setShouldRevert(bool _shouldRevert, string calldata _reason) external {
        shouldRevert = _shouldRevert;
        revertReason = _reason;
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        return (assets * 1e18) / exchangeRate;
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        return (shares * exchangeRate) / 1e18;
    }

    function maxDepositCollateral(address) external pure returns (uint256) {
        return type(uint256).max;
    }

    function previewDepositCollateral(uint256 assets) external view returns (uint256) {
        if (shouldRevert) revert(revertReason);
        return convertToShares(assets);
    }

    function depositCollateral(uint256 assets, address receiver) external returns (uint256) {
        if (shouldRevert) revert(revertReason);

        uint256 shares = convertToShares(assets);
        totalAssetsAmount += assets;
        totalSharesAmount += shares;
        balanceOf[receiver] += shares;

        emit Deposit(msg.sender, receiver, assets, shares);
        emit Transfer(address(0), receiver, shares);

        return shares;
    }

    function maxMintCollateral(address) external pure returns (uint256) {
        return type(uint256).max;
    }

    function previewMintCollateral(uint256 shares) external view returns (uint256) {
        if (shouldRevert) revert(revertReason);
        return convertToAssets(shares);
    }

    function mintCollateral(uint256 shares, address receiver) external returns (uint256) {
        if (shouldRevert) revert(revertReason);

        uint256 assets = convertToAssets(shares);
        totalAssetsAmount += assets;
        totalSharesAmount += shares;
        balanceOf[receiver] += shares;

        emit Deposit(msg.sender, receiver, assets, shares);
        emit Transfer(address(0), receiver, shares);

        return assets;
    }

    function maxWithdrawCollateral(address owner) external view returns (uint256) {
        return convertToAssets(balanceOf[owner]);
    }

    function previewWithdrawCollateral(uint256 assets) external view returns (uint256) {
        if (shouldRevert) revert(revertReason);
        return convertToShares(assets);
    }

    function withdrawCollateral(uint256 assets, address receiver, address owner) external returns (uint256) {
        if (shouldRevert) revert(revertReason);

        uint256 shares = convertToShares(assets);
        require(balanceOf[owner] >= shares, "Insufficient shares");

        balanceOf[owner] -= shares;
        totalSharesAmount -= shares;
        totalAssetsAmount -= assets;

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        emit Transfer(owner, address(0), shares);

        return shares;
    }

    function maxRedeemCollateral(address owner) external view returns (uint256) {
        return balanceOf[owner];
    }

    function previewRedeemCollateral(uint256 shares) external view returns (uint256) {
        if (shouldRevert) revert(revertReason);
        return convertToAssets(shares);
    }

    function redeemCollateral(uint256 shares, address receiver, address owner) external returns (uint256) {
        if (shouldRevert) revert(revertReason);

        require(balanceOf[owner] >= shares, "Insufficient shares");

        uint256 assets = convertToAssets(shares);
        balanceOf[owner] -= shares;
        totalSharesAmount -= shares;
        totalAssetsAmount -= assets;

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        emit Transfer(owner, address(0), shares);

        return assets;
    }
}
