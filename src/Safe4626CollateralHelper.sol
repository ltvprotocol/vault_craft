// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC4626Collateral} from "./interfaces/IERC4626Collateral.sol";

contract Safe4626CollateralHelper {
    error SlippageExceeded(uint256 expected, uint256 actual, uint256 minRequired);
    error InsufficientBalance(uint256 required, uint256 available);
    error InvalidVault(address vault);

    function safeDepositCollateral(IERC4626Collateral vault, uint256 assets, address receiver, uint256 minSharesOut)
        external
        returns (uint256 shares)
    {
        if (address(vault) == address(0)) revert InvalidVault(address(vault));

        shares = vault.depositCollateral(assets, receiver);
        if (shares < minSharesOut) revert SlippageExceeded(shares, minSharesOut, minSharesOut);
    }

    function safeMintCollateral(IERC4626Collateral vault, uint256 shares, address receiver, uint256 maxAssetsIn)
        external
        returns (uint256 assets)
    {
        if (address(vault) == address(0)) revert InvalidVault(address(vault));

        assets = vault.mintCollateral(shares, receiver);
        if (assets > maxAssetsIn) revert SlippageExceeded(maxAssetsIn, assets, maxAssetsIn);
    }

    function safeWithdrawCollateral(
        IERC4626Collateral vault,
        uint256 assets,
        address receiver,
        address owner,
        uint256 maxSharesOut
    ) external returns (uint256 shares) {
        if (address(vault) == address(0)) revert InvalidVault(address(vault));

        shares = vault.withdrawCollateral(assets, receiver, owner);
        if (shares > maxSharesOut) revert SlippageExceeded(maxSharesOut, shares, maxSharesOut);
    }

    function safeRedeemCollateral(
        IERC4626Collateral vault,
        uint256 shares,
        address receiver,
        address owner,
        uint256 minAssetsOut
    ) external returns (uint256 assets) {
        if (address(vault) == address(0)) revert InvalidVault(address(vault));

        assets = vault.redeemCollateral(shares, receiver, owner);
        if (assets < minAssetsOut) revert SlippageExceeded(assets, minAssetsOut, minAssetsOut);
    }
}
