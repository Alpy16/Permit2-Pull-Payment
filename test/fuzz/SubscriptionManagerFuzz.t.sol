//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SubscriptionManager} from "src/SubscriptionManager.sol";
import {Test} from "forge-std/Test.sol";
import {TestToken} from "src/TestToken.sol";
import {ISignatureTransfer} from "lib/permit2/src/interfaces/ISignatureTransfer.sol";

contract SubscriptionManagerTest is Test {
    SubscriptionManager subManager;
    TestToken token = new TestToken();
    address owner = address(0x1);
    address user = address(0x2);
    address permit2 = address(0x4);
    uint256 amount = 100;
    uint256 interval = 30 * 86400;

    function setUp() public {
        vm.prank(owner);
        subManager = new SubscriptionManager(permit2);
    }

    //fuzzing this is pretty pointless, it just writes to storage and has no conditionals etc. Its just for practice/demonstration
    function testFuzz_CreateSubscription(
        address user,
        address token,
        uint256 amount,
        uint256 interval,
        uint256 nextCharge
    ) public {
        vm.assume(user != address(0));
        vm.assume(token != address(0));
        vm.assume(amount > 0);
        vm.assume(interval > 0);
        vm.assume(nextCharge >= block.timestamp);

        // Bound values to realistic ranges to avoid overflows
        amount = bound(amount, 1, 1e30);
        interval = bound(interval, 1, 365 days);
        nextCharge = bound(
            nextCharge,
            block.timestamp,
            block.timestamp + 365 days
        );

        vm.prank(owner);
        subManager.createSubscription(
            user,
            token,
            amount,
            interval,
            nextCharge
        );

        SubscriptionManager.Subscription memory s = subManager.getSubscription(
            user
        );

        // Check all struct fields match what the function writes
        assertEq(s.amount, amount, "amount mismatch");
        assertEq(s.interval, interval, "interval mismatch");
        assertEq(s.nextCharge, nextCharge, "nextCharge mismatch");
        assertEq(s.token, token, "token mismatch");
        assertTrue(s.active, "subscription should be active");
        assertFalse(s.firstChargeCompleted, "first charge must be false");
    }

    function testFuzz_FirstCharge(
        address user,
        uint256 amount,
        uint256 interval,
        uint256 nextCharge,
        uint256 permitAmount,
        uint256 permitDeadline
    ) public {
        vm.assume(user != address(0));
        vm.assume(amount > 0);
        vm.assume(interval > 0);

        amount = bound(amount, 1, 1e30);
        interval = bound(interval, 1, 365 days);

        nextCharge = bound(
            nextCharge,
            block.timestamp,
            block.timestamp + 365 days
        );

        permitAmount = bound(permitAmount, 0, 1e30);
        permitDeadline = bound(
            permitDeadline,
            block.timestamp,
            block.timestamp + 365 days
        );

        address tokenAddr = address(token);

        // Create subscription
        vm.prank(owner);
        subManager.createSubscription(
            user,
            tokenAddr,
            amount,
            interval,
            nextCharge
        );

        // Mint & approve token
        token.mint(user, permitAmount);

        vm.prank(user);
        token.approve(permit2, type(uint256).max);

        vm.warp(nextCharge);

        // Build permit
        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer
            .PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({
                    token: tokenAddr,
                    amount: permitAmount
                }),
                nonce: 0,
                deadline: permitDeadline
            });

        bytes memory permitData = abi.encode(permit);
        bytes memory signature = bytes("sig");

        vm.mockCall(permit2, abi.encodeWithSelector(bytes4(0x0d1b5f50)), "");

        bool shouldRevert = (permitAmount < amount) ||
            (permitDeadline < block.timestamp);

        // Revert branch — FIRST charge should revert
        if (shouldRevert) {
            vm.prank(owner);
            vm.expectRevert();
            subManager.chargeSubscription(user, permitData, signature);
            return;
        }

        // Success branch — mock Permit2 and call ONCE
        vm.mockCall(
            permit2,
            abi.encodeWithSelector(bytes4(0x0d1b5f50)), // selector for permitTransferFrom
            ""
        );

        vm.prank(owner);
        subManager.chargeSubscription(user, permitData, signature);

        // Now assert post-conditions
        SubscriptionManager.Subscription memory s = subManager.getSubscription(
            user
        );
        assertTrue(s.firstChargeCompleted);
        assertEq(s.nextCharge, nextCharge + interval);

        assertTrue(s.firstChargeCompleted);
        assertEq(s.nextCharge, nextCharge + interval);
    }

    function testFuzz_RecurringCharge(
        address user_,
        uint256 amount_,
        uint256 interval_,
        uint256 nextCharge_,
        uint256 balance_,
        uint256 allowance_
    ) public {
        vm.assume(user_ != address(0));
        vm.assume(amount_ > 0);
        vm.assume(interval_ > 0);

        amount_ = bound(amount_, 1, 1e30);
        interval_ = bound(interval_, 1 hours, 365 days);
        nextCharge_ = bound(
            nextCharge_,
            block.timestamp,
            block.timestamp + 365 days
        );

        uint256 minBalance = amount_ > 5e29 ? amount_ : amount_ * 2;
        balance_ = bound(balance_, minBalance, 1e30);
        allowance_ = bound(allowance_, amount_, 1e30);

        address tokenAddr = address(token);
        address treasury = subManager.treasury();

        // Create subscription
        vm.prank(owner);
        subManager.createSubscription(
            user_,
            tokenAddr,
            amount_,
            interval_,
            nextCharge_
        );

        // Mint balance for user
        token.mint(user_, balance_);

        // Approve Permit2 allowance
        vm.prank(user_);
        token.approve(permit2, allowance_);

        // Perform the initial charge via permit so we can transition into recurring billing
        ISignatureTransfer.PermitTransferFrom memory firstPermit = ISignatureTransfer
            .PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({
                    token: tokenAddr,
                    amount: amount_
                }),
                nonce: 0,
                deadline: block.timestamp + 365 days
            });

        vm.warp(nextCharge_);

        vm.mockCall(
            permit2,
            abi.encodeWithSelector(bytes4(0x0d1b5f50)),
            ""
        );

        vm.prank(owner);
        subManager.chargeSubscription(
            user_,
            abi.encode(firstPermit),
            bytes("sig")
        );

        SubscriptionManager.Subscription memory chargedSub = subManager
            .getSubscription(user_);

        vm.warp(chargedSub.nextCharge);

        // Mock AllowanceTransfer.transferFrom — selector 0x2e1d20f6
        vm.mockCall(
            permit2,
            abi.encodeWithSelector(
                bytes4(0x2e1d20f6),
                user_,
                treasury,
                uint160(amount_),
                tokenAddr
            ),
            ""
        );

        // Success path
        vm.prank(owner);
        subManager.chargeSubscription(user_, "", "");

        SubscriptionManager.Subscription memory s = subManager.getSubscription(
            user_
        );

        assertTrue(s.firstChargeCompleted);
        assertEq(s.nextCharge, nextCharge_ + 2 * interval_);
    }
}
