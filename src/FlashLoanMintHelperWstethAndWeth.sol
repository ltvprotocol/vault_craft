// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {CommonFlashLoanHelper, IwstEth, ILowLevelVault, IWETH, IstEth} from "src/CommonFlashLoanHelper.sol";

contract FlashLoanMintHelperWstethAndWeth is CommonFlashLoanHelper {
    using SafeERC20 for IwstEth;
    using SafeERC20 for ILowLevelVault;
    using SafeERC20 for IWETH;
    using SafeERC20 for IstEth;

    constructor(address _ltvVault) CommonFlashLoanHelper(_ltvVault) {}

    function previewMintSharesWithFlashLoanCollateral(uint256 sharesToMint)
        public
        view
        returns (uint256 assetsCollateral)
    {
        (assetsCollateral,) = _previewMintSharesWithFlashLoanCollateral(sharesToMint);
    }

    function mintSharesWithFlashLoanCollateral(uint256 sharesToMint) external returns (uint256) {
        (uint256 netWstEth, uint256 flashAmount) = _previewMintSharesWithFlashLoanCollateral(sharesToMint);

        _startFlashLoan(flashAmount, abi.encode(msg.sender, sharesToMint, netWstEth));

        return netWstEth;
    }

    function _handleFlashLoan(bytes memory userData, uint256 flashAmount) internal override {
        (address user, uint256 sharesToMint, uint256 assetsCollateral) =
            abi.decode(userData, (address, uint256, uint256));

        WETH.withdraw(flashAmount);


        uint256 collateralFromFlash = WSTETH.getWstETHByStETH(flashAmount);
        address(WSTETH).call{value: flashAmount}("");

        WSTETH.safeTransferFrom(user, address(this), assetsCollateral);

        WSTETH.forceApprove(address(LTV_VAULT), collateralFromFlash + assetsCollateral);
        // shares to mint are not expected to exceed int256 max value
        // forge-lint: disable-next-line(unsafe-typecast)
        LTV_VAULT.executeLowLevelRebalanceShares(int256(sharesToMint));

        WETH.safeTransfer(address(BALANCER_VAULT), flashAmount);

        LTV_VAULT.safeTransfer(user, sharesToMint);

        emit SharesMinted(user, sharesToMint);
    }

    function _previewMintSharesWithFlashLoanCollateral(uint256 sharesToMint) internal view returns (uint256, uint256) {
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
}
