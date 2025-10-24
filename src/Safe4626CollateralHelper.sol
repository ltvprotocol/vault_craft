// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC4626Collateral} from "./interfaces/IERC4626Collateral.sol";

contract Safe4626CollateralHelper {
    error SlippageExceeded(uint256 actual);
    error InvalidVault(address vault);

    function safeDepositCollateral(IERC4626Collateral vault, uint256 assets, address receiver, uint256 minSharesOut)
        external
        returns (uint256 shares)
    {
        require(address(vault) != address(0), InvalidVault(address(vault)));

        try vault.depositCollateral(assets, receiver) returns (uint256 returnedShares) {
            shares = returnedShares;
            require((shares >= minSharesOut), SlippageExceeded(shares));
        } catch {
            revert InvalidVault(address(vault));
        }
    }

    function safeMintCollateral(IERC4626Collateral vault, uint256 shares, address receiver, uint256 maxAssetsIn)
        external
        returns (uint256 assets)
    {
        require(address(vault) != address(0), InvalidVault(address(vault)));

        try vault.mintCollateral(shares, receiver) returns (uint256 returnedAssets) {
            assets = returnedAssets;
            require((assets <= maxAssetsIn), SlippageExceeded(assets));
        } catch {
            revert InvalidVault(address(vault));
        }
    }

    function safeWithdrawCollateral(
        IERC4626Collateral vault,
        uint256 assets,
        address receiver,
        address owner,
        uint256 maxSharesIn
    ) external returns (uint256 shares) {
        require(address(vault) != address(0), InvalidVault(address(vault)));

        try vault.withdrawCollateral(assets, receiver, owner) returns (uint256 returnedShares) {
            shares = returnedShares;
            require((shares <= maxSharesIn), SlippageExceeded(shares));
        } catch {
            revert InvalidVault(address(vault));
        }
    }

    function safeRedeemCollateral(
        IERC4626Collateral vault,
        uint256 shares,
        address receiver,
        address owner,
        uint256 minAssetsOut
    ) external returns (uint256 assets) {
        require(address(vault) != address(0), InvalidVault(address(vault)));

        try vault.redeemCollateral(shares, receiver, owner) returns (uint256 returnedAssets) {
            assets = returnedAssets;
            require((assets >= minAssetsOut), SlippageExceeded(assets));
        } catch {
            revert InvalidVault(address(vault));
        }
    }
}
