// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC4626} from "../../src/interfaces/IERC4626.sol";
import {IERC20} from "../../src/interfaces/IERC4626.sol";

contract MockERC4626Vault is IERC4626 {
    IERC20 public immutable assetToken;
    uint256 public totalAssetsAmount;
    uint256 public totalSharesAmount;
    uint256 public exchangeRate = 1e18; // 1:1 by default
    bool public shouldRevert;
    string public revertReason;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    string public name = "Mock Vault";
    string public symbol = "MOCK";
    uint8 public decimals = 18;
    
    constructor(address _asset) {
        assetToken = IERC20(_asset);
    }
    
    function setExchangeRate(uint256 _rate) external {
        exchangeRate = _rate;
    }
    
    function setShouldRevert(bool _shouldRevert, string calldata _reason) external {
        shouldRevert = _shouldRevert;
        revertReason = _reason;
    }
    
    function totalSupply() external view override returns (uint256) {
        return totalSharesAmount;
    }
    
    function transfer(address to, uint256 value) external override returns (bool) {
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }
    
    function approve(address spender, uint256 value) external override returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 value) external override returns (bool) {
        allowance[from][msg.sender] -= value;
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
        return true;
    }
    
    function asset() external view override returns (address) {
        return address(assetToken);
    }
    
    function totalAssets() external view override returns (uint256) {
        return totalAssetsAmount;
    }
    
    function convertToShares(uint256 assets) public view override returns (uint256) {
        return (assets * 1e18) / exchangeRate;
    }
    
    function convertToAssets(uint256 shares) public view override returns (uint256) {
        return (shares * exchangeRate) / 1e18;
    }
    
    function maxDeposit(address) external pure override returns (uint256) {
        return type(uint256).max;
    }
    
    function previewDeposit(uint256 assets) external view override returns (uint256) {
        if (shouldRevert) revert(revertReason);
        return convertToShares(assets);
    }
    
    function deposit(uint256 assets, address receiver) external override returns (uint256) {
        if (shouldRevert) revert(revertReason);
        
        uint256 shares = convertToShares(assets);
        totalAssetsAmount += assets;
        totalSharesAmount += shares;
        balanceOf[receiver] += shares;
        
        emit Deposit(msg.sender, receiver, assets, shares);
        emit Transfer(address(0), receiver, shares);
        
        return shares;
    }
    
    function maxMint(address) external pure override returns (uint256) {
        return type(uint256).max;
    }
    
    function previewMint(uint256 shares) external view override returns (uint256) {
        if (shouldRevert) revert(revertReason);
        return convertToAssets(shares);
    }
    
    function mint(uint256 shares, address receiver) external override returns (uint256) {
        if (shouldRevert) revert(revertReason);
        
        uint256 assets = convertToAssets(shares);
        totalAssetsAmount += assets;
        totalSharesAmount += shares;
        balanceOf[receiver] += shares;
        
        emit Deposit(msg.sender, receiver, assets, shares);
        emit Transfer(address(0), receiver, shares);
        
        return assets;
    }
    
    function maxWithdraw(address owner) external view override returns (uint256) {
        return convertToAssets(balanceOf[owner]);
    }
    
    function previewWithdraw(uint256 assets) external view override returns (uint256) {
        if (shouldRevert) revert(revertReason);
        return convertToShares(assets);
    }
    
    function withdraw(uint256 assets, address receiver, address owner) external override returns (uint256) {
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
    
    function maxRedeem(address owner) external view override returns (uint256) {
        return balanceOf[owner];
    }
    
    function previewRedeem(uint256 shares) external view override returns (uint256) {
        if (shouldRevert) revert(revertReason);
        return convertToAssets(shares);
    }
    
    function redeem(uint256 shares, address receiver, address owner) external override returns (uint256) {
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
