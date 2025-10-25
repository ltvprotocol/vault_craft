// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

interface IFlashLoanHelperEvents {
    event SharesMinted(address indexed user, uint256 amountMinted);
    event SharesBurned(address indexed user, uint256 amountBurned);
}
