// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {ILowLevelVault} from "src/interfaces/ILowLevelVault.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract GhostRedeemHelper {
    using SafeERC20 for IERC20;
    using SafeERC20 for ILowLevelVault;

    error InvalidRebalanceMode();

    ILowLevelVault public immutable GHOST_VAULT;

    constructor(address _ltvVault) {
        GHOST_VAULT = ILowLevelVault(_ltvVault);
    }

    function previewRedeemSharesWithCurveAndFlashLoanBorrow(uint256 sharesToRedeem) public view returns (uint256) {
        (int256 collateral, int256 borrow) = GHOST_VAULT.previewLowLevelRebalanceShares(-int256(sharesToRedeem));

        require(collateral < 0 && borrow < 0 && collateral <= borrow, InvalidRebalanceMode());

        return uint256(borrow - collateral);
    }

    function redeemSharesWithCurveAndFlashLoanBorrow(uint256 sharesToRedeem) external returns (uint256) {
        (int256 collateral, int256 borrow) = GHOST_VAULT.previewLowLevelRebalanceShares(-int256(sharesToRedeem));

        require(collateral < 0 && borrow < 0 && collateral <= borrow, InvalidRebalanceMode());

        uint256 borrowToReturn = uint256(borrow - collateral);
        address borrowAsset = GHOST_VAULT.asset();

        GHOST_VAULT.safeTransferFrom(msg.sender, address(this), sharesToRedeem);
        IERC20(borrowAsset).forceApprove(address(GHOST_VAULT), borrow);
        GHOST_VAULT.executeLowLevelRebalanceShares(-int256(sharesToRedeem));

        IERC20(borrowAsset).safeTransfer(msg.sender, borrowToReturn);
        return uint256(borrow - collateral);
    }
}