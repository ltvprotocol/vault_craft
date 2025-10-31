// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC4626} from "./interfaces/IERC4626.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract Safe4626Helper {
    using SafeERC20 for IERC20;

    error SlippageExceeded(uint256 actual);
    error InvalidVault(address vault);

    function safeDeposit(IERC4626 vault, uint256 assets, address receiver, uint256 minSharesOut)
        external
        returns (uint256 shares)
    {
        require(address(vault) != address(0), InvalidVault(address(vault)));

        try vault.asset() returns (address asset) {
            IERC20(asset).safeTransferFrom(msg.sender, address(this), assets);
            IERC20(asset).forceApprove(address(vault), assets);
        } catch {
            revert InvalidVault(address(vault));
        }
        shares = vault.deposit(assets, receiver);
        require(shares >= minSharesOut, SlippageExceeded(shares));
    }

    function safeMint(IERC4626 vault, uint256 shares, address receiver, uint256 maxAssetsIn)
        external
        returns (uint256 assets)
    {
        require(address(vault) != address(0), InvalidVault(address(vault)));

        assets = vault.previewMint(shares);
        try vault.asset() returns (address asset) {
            IERC20(asset).safeTransferFrom(msg.sender, address(this), assets);
            IERC20(asset).forceApprove(address(vault), assets);
        } catch {
            revert InvalidVault(address(vault));
        }
        assets = vault.mint(shares, receiver);
        require(assets <= maxAssetsIn, SlippageExceeded(assets));
    }

    function safeWithdraw(IERC4626 vault, uint256 assets, address receiver, address owner, uint256 maxSharesOut)
        external
        returns (uint256 shares)
    {
        require(address(vault) != address(0), InvalidVault(address(vault)));

        shares = vault.withdraw(assets, receiver, owner);
        require(shares <= maxSharesOut, SlippageExceeded(shares));
    }

    function safeRedeem(IERC4626 vault, uint256 shares, address receiver, address owner, uint256 minAssetsOut)
        external
        returns (uint256 assets)
    {
        require(address(vault) != address(0), InvalidVault(address(vault)));

        assets = vault.redeem(shares, receiver, owner);
        require(assets >= minAssetsOut, SlippageExceeded(assets));
    }
}
