// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC4626} from "src/interfaces/IERC4626.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

// Mock vault that requires more assets than previewMint suggests (simulating slippage)
contract MockVaultMintSlippage is IERC4626 {
    using SafeERC20 for IERC20;

    IERC20 public immutable ASSET_TOKEN;
    uint256 private _totalShares;
    uint256 private _totalAssets;
    uint256 public constant slippagePercent = 10;  // 10% slippage

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    string public name = "Mock Vault Mint Slippage";
    string public symbol = "MOCK";
    uint8 public decimals = 18;

    constructor(address _asset) {
        ASSET_TOKEN = IERC20(_asset);
    }

    // ERC20
    function totalSupply() external view returns (uint256) {
        return _totalShares;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 value) external returns (bool) {
        _allowances[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        _spendAllowance(from, msg.sender, value);
        _transfer(from, to, value);
        return true;
    }

    // ERC4626
    function asset() external view returns (address) {
        return address(ASSET_TOKEN);
    }

    function totalAssets() external view returns (uint256) {
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

    function maxDeposit(address) external pure returns (uint256) {
        return type(uint256).max;
    }

    function previewDeposit(uint256 assets) external view returns (uint256) {
        return convertToShares(assets);
    }

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        shares = convertToShares(assets);
        ASSET_TOKEN.safeTransferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
        _totalAssets += assets;
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function maxMint(address) external pure returns (uint256) {
        return type(uint256).max;
    }

    function previewMint(uint256 shares) external view returns (uint256) {
        // Preview shows normal assets (no slippage in preview)
        return convertToAssets(shares);
    }

    function mint(uint256 shares, address receiver) external returns (uint256 assets) {
        assets = convertToAssets(shares);
        // Apply 10% slippage - require more assets than expected
        assets = assets * (100 + slippagePercent) / 100;
        ASSET_TOKEN.safeTransferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
        _totalAssets += assets;
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function maxWithdraw(address owner) external view returns (uint256) {
        return convertToAssets(_balances[owner]);
    }

    function previewWithdraw(uint256 assets) external view returns (uint256) {
        return convertToShares(assets);
    }

    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares) {
        shares = convertToShares(assets);
        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }
        _burn(owner, shares);
        _totalAssets -= assets;
        ASSET_TOKEN.safeTransfer(receiver, assets);
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    function maxRedeem(address owner) external view returns (uint256) {
        return _balances[owner];
    }

    function previewRedeem(uint256 shares) external view returns (uint256) {
        return convertToAssets(shares);
    }

    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets) {
        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }
        assets = convertToAssets(shares);
        _burn(owner, shares);
        _totalAssets -= assets;
        ASSET_TOKEN.safeTransfer(receiver, assets);
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    // Internal
    function _transfer(address from, address to, uint256 value) internal {
        _balances[from] -= value;
        _balances[to] += value;
        emit Transfer(from, to, value);
    }

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

    function _spendAllowance(address owner, address spender, uint256 value) internal {
        uint256 currentAllowance = _allowances[owner][spender];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= value, "ERC20: insufficient allowance");
            unchecked {
                _allowances[owner][spender] = currentAllowance - value;
            }
        }
    }
}

