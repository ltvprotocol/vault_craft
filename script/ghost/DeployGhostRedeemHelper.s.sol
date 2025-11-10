// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {GhostRedeemHelper} from "src/ghost/GhostRedeemHelper.sol";
import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

/*
forge script script/ghost/DeployGhostRedeemHelper.s.sol:DeployGhostRedeemHelperScript -f $RPC_URL --broadcast --private-key $PRIVATE_KEY \
 --json | jq "select(.traces[1][1].arena[3].trace.address!=null) | .traces.[1][1].arena[0].trace.decoded.label,.traces[1][1].arena[3].trace.address"
forge verify-contract -f $RPC_URL --etherscan-api-key $ETHERSCAN_API_KEY CONTRACT_ADDRESS
*/
contract DeployGhostRedeemHelperScript is Script {
    function run() public {
        vm.startBroadcast();
        GhostRedeemHelper helper = new GhostRedeemHelper{salt: bytes32(0)}(0xE2A7f267124AC3E4131f27b9159c78C521A44F3c, 0x249f82caa683a49Fe92F5E9518BbDBE443dfF1A2);
        vm.stopBroadcast();
        console2.log("Ghost redeem helper deployed at", address(helper));
    }
}
