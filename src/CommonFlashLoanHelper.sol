// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IBalancerVault} from "src/interfaces/balancer/IBalancerVault.sol";
import {IFlashLoanRecipient} from "src/interfaces/balancer/IFlashLoanRecipient.sol";
import {ILowLevelVault} from "src/interfaces/ILowLevelVault.sol";
import {IWETH} from "src/interfaces/tokens/IWETH.sol";
import {IstEth} from "src/interfaces/tokens/IstEth.sol";
import {IwstEth} from "src/interfaces/tokens/IwstEth.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IFlashLoanHelperErrors} from "src/interfaces/IFlashLoanHelperErrors.sol";
import {IFlashLoanHelperEvents} from "src/interfaces/IFlashLoanHelperEvents.sol";

abstract contract CommonFlashLoanHelper is IFlashLoanHelperErrors, IFlashLoanHelperEvents {
    IBalancerVault constant BALANCER_VAULT = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IWETH constant WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IstEth constant STETH = IstEth(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    IwstEth constant WSTETH = IwstEth(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);

    ILowLevelVault public immutable LTV_VAULT;

    error Unauthorized();

    constructor(address _ltvVault) {
        LTV_VAULT = ILowLevelVault(_ltvVault);
    }

    function _startFlashLoan(uint256 flashAmount, bytes memory data) internal {
        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = WETH;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = flashAmount;

        BALANCER_VAULT.flashLoan(IFlashLoanRecipient(address(this)), tokens, amounts, data);
    }

    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        require(msg.sender == address(BALANCER_VAULT), UnauthorizedFlashLoan());
        require(address(tokens[0]) == address(WETH) && feeAmounts[0] == 0, InvalidFlashLoanParams());

        _handleFlashLoan(userData, amounts[0]);
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
