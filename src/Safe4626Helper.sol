// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC4626} from "./interfaces/IERC4626.sol";

contract Safe4626Helper {
    error SlippageExceeded(uint256 expected, uint256 actual, uint256 minRequired);
    error InvalidVault(address vault);

    function safeDeposit(IERC4626 vault, uint256 assets, address receiver, uint256 minSharesOut)
        external
        returns (uint256 shares)
    {
        require(address(vault) != address(0), InvalidVault(address(vault)));

        shares = vault.deposit(assets, receiver);
        if (shares < minSharesOut) revert SlippageExceeded(shares, minSharesOut, minSharesOut);
    }

    function safeMint(IERC4626 vault, uint256 shares, address receiver, uint256 maxAssetsIn)
        external
        returns (uint256 assets)
    {
        require(address(vault) != address(0), InvalidVault(address(vault)));

        assets = vault.mint(shares, receiver);
        if (assets > maxAssetsIn) revert SlippageExceeded(maxAssetsIn, assets, maxAssetsIn);
    }

    function safeWithdraw(IERC4626 vault, uint256 assets, address receiver, address owner, uint256 maxSharesOut)
        external
        returns (uint256 shares)
    {
        require(address(vault) != address(0), InvalidVault(address(vault)));

        shares = vault.withdraw(assets, receiver, owner);
        if (shares > maxSharesOut) revert SlippageExceeded(maxSharesOut, shares, maxSharesOut);
    }

    function safeRedeem(IERC4626 vault, uint256 shares, address receiver, address owner, uint256 minAssetsOut)
        external
        returns (uint256 assets)
    {
        require(address(vault) != address(0), InvalidVault(address(vault)));

        assets = vault.redeem(shares, receiver, owner);
        if (assets < minAssetsOut) revert SlippageExceeded(assets, minAssetsOut, minAssetsOut);
    }
}
