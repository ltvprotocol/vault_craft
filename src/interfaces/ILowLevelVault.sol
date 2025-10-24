// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILowLevelVault is IERC20 {
    function previewLowLevelRebalanceShares(int256 deltaShares)
        external
        view
        returns (int256 deltaCollateral, int256 deltaBorrow);
    function executeLowLevelRebalanceShares(int256 deltaShares)
        external
        returns (int256 deltaCollateral, int256 deltaBorrow);
}
