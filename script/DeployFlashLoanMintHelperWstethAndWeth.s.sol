// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {FlashLoanMintHelperWstethAndWeth} from "src/FlashLoanMintHelperWstethAndWeth.sol";
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

/*
forge script script/DeployFlashLoanMintHelperWstethAndWeth.s.sol:DeployFlashLoanMintHelperWstethAndWeth -f $RPC_URL --broadcast --private-key $PRIVATE_KEY
forge verify-contract -f $RPC_URL --etherscan-api-key $ETHERSCAN_API_KEY CONTRACT_ADDRESS
*/
contract DeployFlashLoanMintHelperWstethAndWeth is Script {
    function run() public {
        if (block.chainid == 1) {
            address lidoVault = vm.envAddress("LIDO_VAULT");
            vm.startBroadcast();
            FlashLoanMintHelperWstethAndWeth helper = new FlashLoanMintHelperWstethAndWeth(lidoVault);
            vm.stopBroadcast();
            console.log("Flash loan mint helper deployed at", address(helper));
        } else {
            revert("Unsupported chain");
        }
    }
}
