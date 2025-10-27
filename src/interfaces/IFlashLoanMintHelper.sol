// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

interface IFlashLoanMintHelper {
    function previewMintSharesWithFlashLoanCollateral(uint256 sharesToMint) external view returns (uint256);
    function mintSharesWithFlashLoanCollateral(uint256 sharesToMint) external returns (uint256);

    function previewRedeemSharesWithCurveAndFlashLoanBorrow(uint256 sharesToRedeem) external view returns (uint256);
    function redeemSharesWithCurveAndFlashLoan(uint256 sharesToRedeem, uint256 minWEth) external returns (uint256);
}
