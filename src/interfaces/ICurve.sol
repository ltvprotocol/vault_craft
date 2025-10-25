// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

interface ICurve {
    // forge-lint: disable-next-line
    function get_dy(int128 i, int128 j, uint256 dx) external view returns (uint256);

    function exchange(int128 i, int128 j, uint256 dx, uint256 minDy) external payable returns (uint256);
}
