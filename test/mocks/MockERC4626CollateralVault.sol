// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC4626Collateral} from "../../src/interfaces/IERC4626Collateral.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockERC4626CollateralVault is IERC4626Collateral {
    using SafeERC20 for IERC20;

    IERC20 public immutable ASSET_TOKEN;
    uint256 private _totalShares;
    uint256 private _totalAssets;

    mapping(address => uint256) private _balances;

    constructor(address _asset) {
        ASSET_TOKEN = IERC20(_asset);
    }

    // ERC4626Collateral
    function assetCollateral() external view returns (address) {
        return address(ASSET_TOKEN);
    }

    function totalAssets() public view returns (uint256) {
        return _totalAssets;
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        if (_totalAssets == 0) return assets;
        return (assets * _totalShares) / _totalAssets;
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        if (_totalShares == 0) return shares;
        return (shares * _totalAssets) / _totalShares;
    }

    function maxDepositCollateral(address) external pure returns (uint256) {
        return type(uint256).max;
    }

    function previewDepositCollateral(uint256 assets) external view returns (uint256) {
        return convertToShares(assets);
    }

    function depositCollateral(uint256 assets, address receiver) external returns (uint256 shares) {
        shares = convertToShares(assets);
        ASSET_TOKEN.safeTransferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
        _totalAssets += assets;
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function maxMintCollateral(address) external pure returns (uint256) {
        return type(uint256).max;
    }

    function previewMintCollateral(uint256 shares) external view returns (uint256) {
        return convertToAssets(shares);
    }

    function mintCollateral(uint256 shares, address receiver) external returns (uint256 assets) {
        assets = convertToAssets(shares);
        ASSET_TOKEN.safeTransferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
        _totalAssets += assets;
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function maxWithdrawCollateral(address owner) external view returns (uint256) {
        return convertToAssets(_balances[owner]);
    }

    function previewWithdrawCollateral(uint256 assets) external view returns (uint256) {
        return convertToShares(assets);
    }

    function withdrawCollateral(uint256 assets, address receiver, address owner) external returns (uint256 shares) {
        shares = convertToShares(assets);
        require(_balances[owner] >= shares, "Insufficient shares");
        _burn(owner, shares);
        _totalAssets -= assets;
        ASSET_TOKEN.safeTransfer(receiver, assets);
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    function maxRedeemCollateral(address owner) external view returns (uint256) {
        return _balances[owner];
    }

    function previewRedeemCollateral(uint256 shares) external view returns (uint256) {
        return convertToAssets(shares);
    }

    function redeemCollateral(uint256 shares, address receiver, address owner) external returns (uint256 assets) {
        require(_balances[owner] >= shares, "Insufficient shares");
        assets = convertToAssets(shares);
        _burn(owner, shares);
        _totalAssets -= assets;
        ASSET_TOKEN.safeTransfer(receiver, assets);
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    // Helpers
    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    // Internal
    function _mint(address to, uint256 value) internal {
        _totalShares += value;
        _balances[to] += value;
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint256 value) internal {
        _balances[from] -= value;
        _totalShares -= value;
        emit Transfer(from, address(0), value);
    }

    event Transfer(address indexed from, address indexed to, uint256 value);

    function mintFreeTokens(address to, uint256 value) external {
        _mint(to, value);
    }
}
