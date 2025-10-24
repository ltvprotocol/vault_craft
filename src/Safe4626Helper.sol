// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC4626} from "./interfaces/IERC4626.sol";

contract Safe4626Helper {
    error SlippageExceeded(uint256 actual);
    error InvalidVault(address vault);

    function safeDeposit(IERC4626 vault, uint256 assets, address receiver, uint256 minSharesOut)
        external
        returns (uint256 shares)
    {
        try vault.deposit(assets, receiver) returns (uint256 returnedShares) {
            shares = returnedShares;
            require((shares >= minSharesOut), SlippageExceeded(shares));
        } catch {
            revert InvalidVault(address(vault));
        }
    }

    function safeMint(IERC4626 vault, uint256 shares, address receiver, uint256 maxAssetsIn)
        external
        returns (uint256 assets)
    {
        try vault.mint(shares, receiver) returns (uint256 returnedAssets) {
            assets = returnedAssets;
            require((assets <= maxAssetsIn), SlippageExceeded(assets));
        } catch {
            revert InvalidVault(address(vault));
        }
    }

    function safeWithdraw(IERC4626 vault, uint256 assets, address receiver, address owner, uint256 maxSharesOut)
        external
        returns (uint256 shares)
    {
        try vault.withdraw(assets, receiver, owner) returns (uint256 returnedShares) {
            shares = returnedShares;
            require((shares <= maxSharesOut), SlippageExceeded(shares));
        } catch {
            revert InvalidVault(address(vault));
        }
    }

    function safeRedeem(IERC4626 vault, uint256 shares, address receiver, address owner, uint256 minAssetsOut)
        external
        returns (uint256 assets)
    {
        try vault.redeem(shares, receiver, owner) returns (uint256 returnedAssets) {
            assets = returnedAssets;
            require((assets >= minAssetsOut), SlippageExceeded(assets));
        } catch {
            revert InvalidVault(address(vault));
        }
    }
}
