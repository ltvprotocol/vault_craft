// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWETH} from "src/interfaces/tokens/IWETH.sol";
import {IstEth} from "src/interfaces/tokens/IstEth.sol";
import {IwstEth} from "src/interfaces/tokens/IwstEth.sol";
import {IBalancerVault} from "src/interfaces/balancer/IBalancerVault.sol";
import {IFlashLoanRecipient} from "src/interfaces/balancer/IFlashLoanRecipient.sol";
import {ILowLevelVault} from "src/interfaces/ILowLevelVault.sol";
import {IFlashLoanMintHelper} from "src/interfaces/IFlashLoanMintHelper.sol";

contract FlashLoanMintHelperWSTETHandWETH is IFlashLoanRecipient, IFlashLoanMintHelper {
    IBalancerVault constant BALANCER_VAULT = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IWETH constant WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IstEth constant STETH = IstEth(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    IwstEth constant WSTETH = IwstEth(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);

    ILowLevelVault public immutable LTV_VAULT;

    constructor(address _ltvVault) {
        LTV_VAULT = ILowLevelVault(_ltvVault);
    }

    function previewMintSharesWithFlashLoan(uint256 sharesToMint) public view returns (uint256, uint256) {
        (int256 deltaCollateral, int256 deltaBorrow) = LTV_VAULT.previewLowLevelRebalanceShares(int256(sharesToMint));

        if (deltaCollateral <= 0 || deltaBorrow <= 0) {
            revert InvalidRebalanceMode();
        }

        uint256 flashAmount = uint256(deltaBorrow);
        uint256 stEthFromFlash = calculateStETHFromETH(flashAmount);
        uint256 wstEthFromFlash = WSTETH.getWstETHByStETH(stEthFromFlash);
        uint256 netWstEth = uint256(deltaCollateral) - wstEthFromFlash;

        return (netWstEth, flashAmount);
    }

    function calculateStETHFromETH(uint256 ethAmount) public view returns (uint256) {
        uint256 shares = STETH.getSharesByPooledEth(ethAmount);
        uint256 stEthAmount = STETH.getPooledEthByShares(shares);
        return stEthAmount;
    }

    function mintSharesWithFlashLoan(uint256 sharesToMint) external {
        (uint256 netWstEth, uint256 flashAmount) = previewMintSharesWithFlashLoan(sharesToMint);

        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = WETH;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = flashAmount;
        bytes memory userData = abi.encode(msg.sender, sharesToMint, netWstEth);

        BALANCER_VAULT.flashLoan(IFlashLoanRecipient(this), tokens, amounts, userData);
    }

    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external override {
        if (msg.sender != address(BALANCER_VAULT)) {
            revert UnauthorizedFlashLoan();
        }

        if (address(tokens[0]) != address(WETH) || feeAmounts[0] != 0) {
            revert InvalidFlashLoanParams();
        }

        uint256 flashAmount = amounts[0];

        (address user, uint256 sharesToMint, uint256 netWstEth) = abi.decode(userData, (address, uint256, uint256));

        // Convert flash loan WETH -> ETH -> stETH -> wstETH
        WETH.withdraw(flashAmount);
        // if it first time, stEthBefore is 0
        uint256 stEthBefore = STETH.balanceOf(address(this));

        STETH.submit{value: flashAmount}(address(0));
        uint256 stEthReceived = STETH.balanceOf(address(this)) - stEthBefore;

        STETH.approve(address(WSTETH), stEthReceived);
        // because of transferFrom issue in stETH contract 1 wei amount of stETH remains
        uint256 wstReceived = WSTETH.wrap(stEthReceived);

        (int256 deltaCollateral, int256 deltaBorrow) = LTV_VAULT.previewLowLevelRebalanceShares(int256(sharesToMint));

        if (deltaCollateral <= 0 || deltaBorrow <= 0) {
            revert InvalidRebalanceMode();
        }

        uint256 totalCollateralNeeded = uint256(deltaCollateral);

        uint256 wstEthNeeded = totalCollateralNeeded - wstReceived;

        if (wstEthNeeded > netWstEth) {
            revert("Insufficient wstETH approved by user");
        }

        WSTETH.transferFrom(user, address(this), netWstEth);

        // Approve and execute rebalance
        WSTETH.approve(address(LTV_VAULT), totalCollateralNeeded);
        LTV_VAULT.executeLowLevelRebalanceShares(int256(sharesToMint));

        // Repay flash loan
        WETH.transfer(address(BALANCER_VAULT), flashAmount);

        // Transfer shares to user
        LTV_VAULT.transfer(user, sharesToMint);

        // Refund any excess wstETH dust back to user
        uint256 remainingWstEth = WSTETH.balanceOf(address(this));
        if (remainingWstEth > 0) {
            WSTETH.transfer(user, remainingWstEth);
        }

        emit SharesMinted(user, sharesToMint);
    }

    receive() external payable {}
}
