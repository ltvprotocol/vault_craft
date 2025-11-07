// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {ILowLevelVault} from "src/interfaces/ILowLevelVault.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract GhostMintHelper {
    using SafeERC20 for IERC20;
    using SafeERC20 for ILowLevelVault;

    error InvalidRebalanceMode();

    ILowLevelVault public immutable GHOST_VAULT;

    constructor(address _ltvVault) {
        GHOST_VAULT = ILowLevelVault(_ltvVault);
    }

    function previewMintSharesWithFlashLoanCollateral(uint256 sharesToMint) public view returns (uint256) {
        (int256 collateral, int256 borrow) = GHOST_VAULT.previewLowLevelRebalanceShares(int256(sharesToMint));

        require(collateral > 0 && borrow > 0 && collateral >= borrow, InvalidRebalanceMode());

        return uint256(collateral - borrow);
    }

    function mintSharesWithFlashLoanCollateral(uint256 sharesToMint) external returns (uint256) {
        (int256 collateral, int256 borrow) = GHOST_VAULT.previewLowLevelRebalanceShares(int256(sharesToMint));
        require(collateral > 0 && borrow > 0 && collateral >= borrow, InvalidRebalanceMode());

        address collateralAsset = GHOST_VAULT.assetCollateral();

        IERC20(collateralAsset).safeTransferFrom(msg.sender, address(this), uint256(collateral - borrow));

        IERC20(collateralAsset).forceApprove(address(GHOST_VAULT), uint256(collateral));

        GHOST_VAULT.executeLowLevelRebalanceShares(int256(sharesToMint));
        GHOST_VAULT.safeTransfer(msg.sender, sharesToMint);

        return uint256(collateral - borrow);
    }
}
