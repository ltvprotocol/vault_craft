// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ICurve} from "src/interfaces/ICurve.sol";
import {CommonFlashLoanHelper, IwstEth, ILowLevelVault, IWETH, IstEth} from "src/CommonFlashLoanHelper.sol";

contract FlashLoanBurnHelperWstethAndWeth is CommonFlashLoanHelper {
    using SafeERC20 for IwstEth;
    using SafeERC20 for ILowLevelVault;
    using SafeERC20 for IWETH;
    using SafeERC20 for IstEth;

    ICurve constant CURVE = ICurve(0xDC24316b9AE028F1497c275EB9192a3Ea0f67022);

    constructor(address _ltvVault) CommonFlashLoanHelper(_ltvVault) {}

    function previewBurnSharesWithCurveAndFlashLoanBorrow(uint256 sharesToBurn)
        public
        view
        returns (uint256 expectedWEth)
    {
        (expectedWEth,,) = _previewBurnSharesWithCurveAndFlashLoanBorrow(sharesToBurn);
    }

    function burnSharesWithCurveAndFlashLoanBorrow(uint256 sharesToBurn, uint256 minWeth) external returns (uint256) {
        (uint256 expectedWEth, uint256 flashAmount, uint256 stEthToSwap) =
            _previewBurnSharesWithCurveAndFlashLoanBorrow(sharesToBurn);

        require(expectedWEth >= minWeth, SlippageExceeded(expectedWEth, minWeth));

        _startFlashLoan(flashAmount, abi.encode(msg.sender, sharesToBurn, stEthToSwap, expectedWEth));

        return expectedWEth;
    }

    function _handleFlashLoan(bytes memory userData, uint256 flashAmount) internal override {
        (address user, uint256 sharesToBurn, uint256 collateralToSwap, uint256 expectedWEth) =
            abi.decode(userData, (address, uint256, uint256, uint256));

        LTV_VAULT.safeTransferFrom(user, address(this), sharesToBurn);
        WETH.forceApprove(address(LTV_VAULT), flashAmount);
        // shares to burn are not expected to exceed int256 max value
        // forge-lint: disable-next-line(unsafe-typecast)
        LTV_VAULT.executeLowLevelRebalanceShares(-int256(sharesToBurn));

        uint256 stEthToSwap = WSTETH.unwrap(collateralToSwap);
        STETH.forceApprove(address(CURVE), stEthToSwap);
        CURVE.exchange(1, 0, stEthToSwap, 0);

        WETH.deposit{value: expectedWEth + flashAmount}();

        WETH.safeTransfer(user, expectedWEth);
        WETH.safeTransfer(address(BALANCER_VAULT), flashAmount);

        emit SharesBurned(user, sharesToBurn);
    }

    function _previewBurnSharesWithCurveAndFlashLoanBorrow(uint256 sharesToBurn)
        internal
        view
        returns (uint256, uint256, uint256)
    {
        // shares to burn are not expected to exceed int256 max value
        // forge-lint: disable-next-line(unsafe-typecast)
        (int256 deltaCollateral, int256 deltaBorrow) = LTV_VAULT.previewLowLevelRebalanceShares(-int256(sharesToBurn));
        require(deltaCollateral <= 0 && deltaBorrow <= 0, InvalidRebalanceMode());

        // forge-lint: disable-next-line(unsafe-typecast)
        uint256 stEthAmount = STETH.getPooledEthByShares(uint256(-deltaCollateral));

        uint256 eth = CURVE.get_dy(1, 0, stEthAmount);
        // forge-lint: disable-next-line(unsafe-typecast)
        require(eth >= uint256(-deltaBorrow), SlippageExceeded(eth, uint256(-deltaBorrow)));
        // forge-lint: disable-next-line(unsafe-typecast)
        return (eth - uint256(-deltaBorrow), uint256(-deltaBorrow), uint256(-deltaCollateral));
    }
}
