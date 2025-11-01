// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Safe4626CollateralHelper} from "src/Safe4626CollateralHelper.sol";
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

/*
forge script script/DeploySafe4626CollateralHelper.s.sol:DeploySafe4626CollateralHelper -f $RPC_URL --broadcast --private-key $PRIVATE_KEY \
 --json | jq "select(.traces[1][1].arena[3].trace.address!=null) | .traces[1][1].arena[3].trace.address"
forge verify-contract -f $RPC_URL --etherscan-api-key $ETHERSCAN_API_KEY CONTRACT_ADDRESS
*/
contract DeploySafe4626CollateralHelper is Script {
    function run() public {
        vm.startBroadcast();
        Safe4626CollateralHelper helper = new Safe4626CollateralHelper{salt: bytes32(0)}();
        vm.stopBroadcast();
        console.log("Safe4626 collateral helper deployed at", address(helper));
    }
}
