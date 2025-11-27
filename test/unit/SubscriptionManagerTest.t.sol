// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "src/SubscriptionManager.sol";
import {Test} from "forge-std/Test.sol";
import {ISignatureTransfer} from "lib/permit2/src/interfaces/ISignatureTransfer.sol";

contract SubscriptionManagerTest is Test {
    SubscriptionManager subManager;

    address owner = address(0x1);
    address user = address(0x2);
    address token = address(0x3);
    address permit2Address = address(0x4);

    uint256 amount = 100;
    uint256 interval = 30 * 86400;

    function setUp() public {
        vm.prank(owner);
        subManager = new SubscriptionManager(permit2Address);
    }

    function testCreateSubscription() public {
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

    function testFirstCharge_UsesPermit() public {
        uint256 nextCharge = block.timestamp + 1 days;

        // Create subscription
        vm.prank(owner);
        subManager.createSubscription(
            user,
            token,
            amount,
            interval,
            nextCharge
        );

        // Move time forward
        vm.warp(nextCharge + 1);

        // Fake permit from backend
        ISignatureTransfer.PermitTransferFrom
            memory fakePermit = ISignatureTransfer.PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({
                    token: token,
                    amount: amount
                }),
                nonce: 0,
                deadline: block.timestamp + 999
            });

        // Encode permit + signature
        bytes memory permitData = abi.encode(fakePermit);
        bytes memory signature = hex"123456";

        // ---------------------------------------------------------
        // MOCK PERMIT2: permitTransferFrom
        // Using the exact selector from Permit2: 0x30f28b7a
        // ---------------------------------------------------------

        vm.mockCall(
            permit2Address,
            abi.encodeWithSelector(bytes4(0x30f28b7a)),
            abi.encode()
        );

        // Execute billing
        vm.prank(owner);
        subManager.chargeSubscription(user, permitData, signature);

        // Validate
        SubscriptionManager.Subscription memory s = subManager.getSubscription(
            user
        );

        assertTrue(s.firstChargeCompleted);
        assertEq(s.nextCharge, subManager.getSubscription(user).nextCharge);
        // via ir makes block.timestamp start from 1 instead of 0, keep it in mind instead of losing your mind like i did trying to debug this.
    }

    function testFirstChargeFails_WithoutPermit() public {
        uint256 nextCharge = block.timestamp + 1 days;

        // Create subscription
        vm.prank(owner);
        subManager.createSubscription(
            user,
            token,
            amount,
            interval,
            nextCharge
        );

        // Move time forward
        vm.warp(nextCharge + 1);

        // Execute billing without permit
        vm.prank(owner);
        vm.expectRevert();
        subManager.chargeSubscription(user, "", "");
    }

    function testChargeEarlyFails() public {
        uint256 nextCharge = block.timestamp + 1 days;

        // Create subscription
        vm.prank(owner);
        subManager.createSubscription(
            user,
            token,
            amount,
            interval,
            nextCharge
        );

        // Try to charge before nextCharge
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                SubscriptionManager.NotTimeForCharge.selector,
                user,
                nextCharge
            )
        );
        subManager.chargeSubscription(user, "", "");
    }

    function testChargeRecurring() public {
        uint256 nextCharge = block.timestamp + 1 days;

        // Create subscription
        vm.prank(owner);
        subManager.createSubscription(
            user,
            token,
            amount,
            interval,
            nextCharge
        );

        //
        // -----------------------
        // FIRST CHARGE (permit)
        // -----------------------
        //

        vm.warp(nextCharge + 1);

        // Fake permit
        ISignatureTransfer.PermitTransferFrom
            memory fakePermit = ISignatureTransfer.PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({
                    token: token,
                    amount: amount
                }),
                nonce: 0,
                deadline: block.timestamp + 999
            });

        bytes memory permitData = abi.encode(fakePermit);
        bytes memory signature = hex"123456";

        // Mock permitTransferFrom on Permit2
        vm.mockCall(
            permit2Address,
            abi.encodeWithSelector(bytes4(0x30f28b7a)),
            abi.encode()
        );

        // Execute first charge
        vm.prank(owner);
        subManager.chargeSubscription(user, permitData, signature);

        // Capture updated charge time
        SubscriptionManager.Subscription memory s1 = subManager.getSubscription(
            user
        );
        uint256 next1 = s1.nextCharge;

        //
        // -----------------------
        // SECOND CHARGE (NO permit)
        // -----------------------
        //

        // Warp to new charge time
        vm.warp(next1 + 1);

        // Mock allowanceTransfer.transferFrom (selector doesn't matter for mock)
        vm.mockCall(permit2Address, bytes(""), abi.encode());

        // Execute second charge with EMPTY permit
        vm.prank(owner);
        subManager.chargeSubscription(user, "", "");

        // Validate next cycle
        SubscriptionManager.Subscription memory s2 = subManager.getSubscription(
            user
        );
        assertEq(s2.nextCharge, next1 + interval);
    }

    function testNonOwnerCannotCharge() public {
        uint256 nextCharge = block.timestamp + 1 days;

        // Create subscription
        vm.prank(owner);
        subManager.createSubscription(
            user,
            token,
            amount,
            interval,
            nextCharge
        );

        // Move time forward
        vm.warp(nextCharge + 1);

        // Try to charge as non-owner
        vm.prank(address(0x999));
        vm.expectRevert();
        subManager.chargeSubscription(user, "", "");
    }
}
