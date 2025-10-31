// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC4626Collateral} from "./interfaces/IERC4626Collateral.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract Safe4626CollateralHelper {
    using SafeERC20 for IERC20;

    error SlippageExceeded(uint256 actual);
    error InvalidVault(address vault);

    function safeDepositCollateral(IERC4626Collateral vault, uint256 assets, address receiver, uint256 minSharesOut)
        external
        returns (uint256 shares)
    {
        require(address(vault) != address(0), InvalidVault(address(vault)));

        try vault.assetCollateral() returns (IERC20 asset) {
            asset.safeTransferFrom(msg.sender, address(this), assets);
            asset.safeApprove(address(vault), assets);
        } catch {
            revert InvalidVault(address(vault));
        }
        shares = vault.depositCollateral(assets, receiver);
        require(shares >= minSharesOut, SlippageExceeded(shares));
    }

    function safeMintCollateral(IERC4626Collateral vault, uint256 shares, address receiver, uint256 maxAssetsIn)
        external
        returns (uint256 assets)
    {
        require(address(vault) != address(0), InvalidVault(address(vault)));

        uint256 assets = vault.previewMintCollateral(shares);
        try vault.assetCollateral() returns (IERC20 asset) {
            asset.safeTransferFrom(msg.sender, address(this), assets);
            asset.safeApprove(address(vault), assets);
        } catch {
            revert InvalidVault(address(vault));
        }
        assets = vault.mintCollateral(shares, receiver);
        require(assets <= maxAssetsIn, SlippageExceeded(assets));
    }

    function safeWithdrawCollateral(
        IERC4626Collateral vault,
        uint256 assets,
        address receiver,
        address owner,
        uint256 maxSharesIn
    ) external returns (uint256 shares) {
        require(address(vault) != address(0), InvalidVault(address(vault)));

        shares = vault.withdrawCollateral(assets, receiver, owner);
        require(shares <= maxSharesIn, SlippageExceeded(shares));
    }

    function safeRedeemCollateral(
        IERC4626Collateral vault,
        uint256 shares,
        address receiver,
        address owner,
        uint256 minAssetsOut
    ) external returns (uint256 assets) {
        require(address(vault) != address(0), InvalidVault(address(vault)));

        assets = vault.redeemCollateral(shares, receiver, owner);
        require(assets >= minAssetsOut, SlippageExceeded(assets));
    }
}
