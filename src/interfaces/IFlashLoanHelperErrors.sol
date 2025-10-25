// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

interface IFlashLoanHelperErrors {
    error InvalidRebalanceMode();
    error UnauthorizedFlashLoan();
    error InvalidFlashLoanParams();
    error FailedToWrapShares();
    error SlippageExceeded(uint256 actual, uint256 minRequired);
}
