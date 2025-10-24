// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

interface IFlashLoanMintHelper {
    function previewMintSharesWithFlashLoanCollateral(uint256 sharesToMint) external view returns (uint256);
    function mintSharesWithFlashLoanCollateral(uint256 sharesToMint) external returns (uint256);

    function previewBurnSharesWithCurveAndFlashLoanBorrow(uint256 sharesToBurn) external view returns (uint256);
    function burnSharesWithCurveAndFlashLoanBorrow(uint256 sharesToBurn, uint256 minWEth) external returns (uint256);

    error InvalidRebalanceMode();
    error UnauthorizedFlashLoan();
    error InvalidFlashLoanParams();
    error FailedToWrapShares();
    error SlippageExceeded(uint256 actual, uint256 minRequired);

    event SharesMinted(address indexed user, uint256 amountMinted);
    event SharesBurned(address indexed user, uint256 amountBurned);
}
