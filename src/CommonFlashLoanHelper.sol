// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {ILowLevelVault} from "src/interfaces/ILowLevelVault.sol";
import {IWETH} from "src/interfaces/tokens/IWETH.sol";
import {IstEth} from "src/interfaces/tokens/IstEth.sol";
import {IwstEth} from "src/interfaces/tokens/IwstEth.sol";
import {IFlashLoanHelperErrors} from "src/interfaces/IFlashLoanHelperErrors.sol";
import {IFlashLoanHelperEvents} from "src/interfaces/IFlashLoanHelperEvents.sol";
import {IMoprho} from "src/interfaces/IMoprho.sol";

abstract contract CommonFlashLoanHelper is IFlashLoanHelperErrors, IFlashLoanHelperEvents {
    IMoprho constant MORPHO = IMoprho(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
    IWETH constant WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IstEth constant STETH = IstEth(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    IwstEth constant WSTETH = IwstEth(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);

    ILowLevelVault public immutable LTV_VAULT;

    error Unauthorized();

    constructor(address _ltvVault) {
        LTV_VAULT = ILowLevelVault(_ltvVault);
    }

    function _startFlashLoan(uint256 flashAmount, bytes memory data) internal {
        MORPHO.flashLoan(address(WETH), flashAmount, data);
    }

    function onMorphoFlashLoan(uint256 assets, bytes memory data) external {
        require(msg.sender == address(MORPHO), UnauthorizedFlashLoan());

        _handleFlashLoan(data, assets);
    }

    function _checkUnauthorizedReceive() internal view virtual {
        if (msg.sender == address(WETH)) {
            return;
        }
        revert Unauthorized();
    }

    receive() external payable {
        _checkUnauthorizedReceive();
    }

    function _handleFlashLoan(bytes memory userData, uint256 flashAmount) internal virtual;
}
