// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {FlashLoanRedeemHelperWstethAndWeth} from "src/FlashLoanRedeemHelperWstethAndWeth.sol";
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

/*
forge script script/DeployFlashLoanRedeemHelperWstethAndWeth.s.sol:DeployFlashLoanRedeemHelperWstethAndWeth -f $RPC_URL --broadcast --private-key $PRIVATE_KEY --json | jq "select(.logs[0]!=null) | .logs[0]"
forge verify-contract -f $RPC_URL --etherscan-api-key $ETHERSCAN_API_KEY CONTRACT_ADDRESS
*/
contract DeployFlashLoanRedeemHelperWstethAndWeth is Script {
    function run() public {
        if (block.chainid == 1) {
            address lidoVault = vm.envAddress("LIDO_VAULT");
            vm.startBroadcast();
            FlashLoanRedeemHelperWstethAndWeth helper = new FlashLoanRedeemHelperWstethAndWeth{salt: bytes32(0)}(lidoVault);
            vm.stopBroadcast();
            console.log("Flash loan redeem helper deployed at", address(helper));
        } else {
            revert("Unsupported chain");
        }
    }
}
