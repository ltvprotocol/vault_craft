// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC4626} from "src/interfaces/IERC4626.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// Mock vault that reverts on mint() call
contract MockVaultMintReverts is IERC4626 {
    IERC20 public immutable ASSET_TOKEN;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    string public name = "Mock Vault Mint Reverts";
    string public symbol = "MOCK";
    uint8 public decimals = 18;

    constructor(address _asset) {
        ASSET_TOKEN = IERC20(_asset);
    }

    function asset() external view returns (address) {
        return address(ASSET_TOKEN);
    }

    function mint(uint256, address) external pure returns (uint256) {
        revert("Mint failed");
    }

    // Stub implementations required by IERC4626
    function totalSupply() external pure returns (uint256) { return 0; }
    function balanceOf(address) external pure returns (uint256) { return 0; }
    function transfer(address, uint256) external pure returns (bool) { return false; }
    function allowance(address, address) external pure returns (uint256) { return 0; }
    function approve(address, uint256) external pure returns (bool) { return false; }
    function transferFrom(address, address, uint256) external pure returns (bool) { return false; }
    function totalAssets() external pure returns (uint256) { return 0; }
    function convertToShares(uint256) external pure returns (uint256) { return 0; }
    function convertToAssets(uint256) external pure returns (uint256) { return 0; }
    function maxDeposit(address) external pure returns (uint256) { return 0; }
    function previewDeposit(uint256) external pure returns (uint256) { return 0; }
    function maxMint(address) external pure returns (uint256) { return 0; }
    function previewMint(uint256 shares) external pure returns (uint256) { return shares; }
    function deposit(uint256, address) external pure returns (uint256) { return 0; }
    function maxWithdraw(address) external pure returns (uint256) { return 0; }
    function previewWithdraw(uint256) external pure returns (uint256) { return 0; }
    function withdraw(uint256, address, address) external pure returns (uint256) { return 0; }
    function maxRedeem(address) external pure returns (uint256) { return 0; }
    function previewRedeem(uint256) external pure returns (uint256) { return 0; }
    function redeem(uint256, address, address) external pure returns (uint256) { return 0; }
}

