//SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {SubscriptionManager} from "../src/SubscriptionManager.sol";
import {Script} from "lib/forge-std/src/Script.sol";
import {Permit2} from "lib/permit2/src/Permit2.sol";
import {IAllowanceTransfer} from "lib/permit2/src/interfaces/IAllowanceTransfer.sol";
import {ISignatureTransfer} from "lib/permit2/src/interfaces/ISignatureTransfer.sol";
import {ERC20} from "lib/solmate/src/tokens/ERC20.sol";

contract DeploySubscriptionManager is Script {
    function run() external {
        vm.startBroadcast();
        Permit2 permit2 = Permit2(0x000000000022D473030F116dDEE9F6B43aC78BA3); //the actual permit2 address
        SubscriptionManager sm = new SubscriptionManager(address(permit2));
        vm.stopBroadcast();
    }
}
