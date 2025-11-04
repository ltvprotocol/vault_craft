// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

interface IMoprho {
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
}
