// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWETH} from "src/interfaces/tokens/IWETH.sol";
import {IstEth} from "src/interfaces/tokens/IstEth.sol";
import {IwstEth} from "src/interfaces/tokens/IwstEth.sol";
import {IBalancerVault} from "src/interfaces/balancer/IBalancerVault.sol";
import {IFlashLoanRecipient} from "src/interfaces/balancer/IFlashLoanRecipient.sol";
import {ILowLevelVault} from "src/interfaces/ILowLevelVault.sol";
import {IFlashLoanMintHelper} from "src/interfaces/IFlashLoanMintHelper.sol";

contract FlashLoanMintHelperWSTETHandWETH is IFlashLoanRecipient, IFlashLoanMintHelper {
    using SafeERC20 for IERC20;
    using SafeERC20 for IwstEth;
    using SafeERC20 for IstEth;
    using SafeERC20 for IWETH;
    using SafeERC20 for ILowLevelVault;

    IBalancerVault constant BALANCER_VAULT = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IWETH constant WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IstEth constant STETH = IstEth(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    IwstEth constant WSTETH = IwstEth(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);

    ILowLevelVault public immutable LTV_VAULT;

    constructor(address _ltvVault) {
        LTV_VAULT = ILowLevelVault(_ltvVault);
    }

    function previewMintSharesWithFlashLoan(uint256 sharesToMint) public view returns (uint256 assetsCollateral) {
        (assetsCollateral,) = _previewMintSharesWithFlashLoan(sharesToMint);
    }

    function mintSharesWithFlashLoan(uint256 sharesToMint) external {
        (uint256 netWstEth, uint256 flashAmount) = _previewMintSharesWithFlashLoan(sharesToMint);

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
        require(msg.sender == address(BALANCER_VAULT), UnauthorizedFlashLoan());
        require(address(tokens[0]) == address(WETH) && feeAmounts[0] == 0, InvalidFlashLoanParams());

        uint256 flashAmount = amounts[0];
        (address user, uint256 sharesToMint, uint256 assetsCollateral) =
            abi.decode(userData, (address, uint256, uint256));

        WETH.withdraw(flashAmount);
        uint256 collateralFromFlash = STETH.submit{value: flashAmount}(address(0));

        _wrapShares(collateralFromFlash);

        WSTETH.safeTransferFrom(user, address(this), assetsCollateral);

        WSTETH.forceApprove(address(LTV_VAULT), collateralFromFlash + assetsCollateral);
        // shares to mint are not expected to exceed int256 max value
        // forge-lint: disable-next-line(unsafe-typecast)
        LTV_VAULT.executeLowLevelRebalanceShares(int256(sharesToMint));

        WETH.safeTransfer(address(BALANCER_VAULT), flashAmount);

        LTV_VAULT.safeTransfer(user, sharesToMint);

        emit SharesMinted(user, sharesToMint);
    }

    receive() external payable {}

    function _previewMintSharesWithFlashLoan(uint256 sharesToMint) internal view returns (uint256, uint256) {
        // shares to mint are not expected to exceed int256 max value
        // forge-lint: disable-next-line(unsafe-typecast)
        (int256 deltaCollateral, int256 deltaBorrow) = LTV_VAULT.previewLowLevelRebalanceShares(int256(sharesToMint));

        require(deltaCollateral > 0 && deltaBorrow > 0, InvalidRebalanceMode());

        // typecast checked above
        // forge-lint: disable-start(unsafe-typecast)
        uint256 flashAmount = uint256(deltaBorrow);
        uint256 collateralFromFlash = STETH.getSharesByPooledEth(flashAmount);
        uint256 assetsCollateral = uint256(deltaCollateral) - collateralFromFlash;
        // forge-lint: disable-end(unsafe-typecast)

        return (assetsCollateral, flashAmount);
    }

    function _wrapShares(uint256 shares) internal {
        uint256 totalShares = STETH.getTotalShares();
        uint256 stEth = (shares * STETH.getTotalPooledEther() + totalShares - 1) / totalShares;

        STETH.forceApprove(address(WSTETH), stEth);
        require(WSTETH.wrap(stEth) == shares, FailedToWrapShares());
    }
}
