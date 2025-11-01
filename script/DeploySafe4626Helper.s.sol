// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Safe4626Helper} from "src/Safe4626Helper.sol";
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

/*
forge script script/DeploySafe4626Helper.s.sol:DeploySafe4626Helper -f $RPC_URL --broadcast --private-key $PRIVATE_KEY
forge verify-contract -f $RPC_URL --etherscan-api-key $ETHERSCAN_API_KEY CONTRACT_ADDRESS
*/
contract DeploySafe4626Helper is Script {
    function run() public {
        vm.startBroadcast();
        Safe4626Helper helper = new Safe4626Helper();
        vm.stopBroadcast();
        console.log("Safe4626 helper deployed at", address(helper));
    }
}
