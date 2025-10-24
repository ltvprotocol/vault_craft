// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IwstEth is IERC20 {
    function wrap(uint256 stEthAmount) external returns (uint256);
    function unwrap(uint256 wstEthAmount) external returns (uint256);
}
