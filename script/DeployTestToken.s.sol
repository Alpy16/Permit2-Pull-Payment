// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Script} from "forge-std/Script.sol";
import {TestToken} from "../src/TestToken.sol";

contract DeployTestToken is Script {
    function run() external {
        vm.startBroadcast();
        new TestToken();
        vm.stopBroadcast();
    }
}
