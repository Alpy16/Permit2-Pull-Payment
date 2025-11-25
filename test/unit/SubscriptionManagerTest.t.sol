//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "src/SubscriptionManager.sol";
import "forge-std/Test.sol";
import "lib/permit2/test/mocks/MockPermit2.sol";

contract SubscriptionManagerTest is Test {
    SubscriptionManager subManager;
    address owner = address(0x1);
    address user = address(0x2);
    address token = address(0x3);
    address permit2Address = address(0x4);

    function setUp() public {
        vm.prank(owner);
        subManager = new SubscriptionManager(permit2Address);
    }

    function testCreateSubscription() public {
        uint256 amount = 100;
        uint256 interval = 30 days;
        uint256 nextCharge = block.timestamp + 1 days;
        vm.prank(owner);
        subManager.createSubscription(
            user,
            token,
            amount,
            interval,
            nextCharge
        );
        SubscriptionManager.Subscription memory sub = subManager
            .getSubscription(user);
        assertEq(sub.amount, amount);
        assertEq(sub.interval, interval);
        assertEq(sub.nextCharge, nextCharge);
        assertEq(sub.active, true);
        assertEq(sub.token, token);
    }

    function testCancelSubscription() public {
        uint256 amount = 100;
        uint256 interval = 30 days;
        uint256 nextCharge = block.timestamp + 1 days;
        vm.prank(owner);
        subManager.createSubscription(
            user,
            token,
            amount,
            interval,
            nextCharge
        );
        vm.prank(owner);
        subManager.cancelSubscription(user);
        SubscriptionManager.Subscription memory sub = subManager
            .getSubscription(user);
        assertEq(sub.active, false);
    }

    /*currently figuring out how tf im gonna make a permit2 signature and permitData for testing chargeSubscription so no charge test yet 

    i need a permit2 mock that can sign for me but my permit2 files are an old version and incompatible with the current one so im stuck rn*/
}
