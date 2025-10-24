// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

interface IFlashLoanMintHelper {
    function previewMintSharesWithFlashLoanCollateral(uint256 sharesToMint) external view returns (uint256);
    function mintSharesWithFlashLoanCollateral(uint256 sharesToMint) external;

    error InvalidRebalanceMode();
    error UnauthorizedFlashLoan();
    error InvalidFlashLoanParams();
    error FailedToWrapShares();

    event SharesMinted(address indexed user, uint256 amountMinted);
}
