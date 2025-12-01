// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Permit2} from "lib/permit2/src/Permit2.sol";
import {ISignatureTransfer} from "lib/permit2/src/interfaces/ISignatureTransfer.sol";
import {IAllowanceTransfer} from "lib/permit2/src/interfaces/IAllowanceTransfer.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract SubscriptionManager is Ownable {
    Permit2 public permit2;
    address public treasury;

    constructor(address _permit2) Ownable(msg.sender) {
        permit2 = Permit2(_permit2);
        treasury = msg.sender;
    }

    event SubscriptionCreated(
        address indexed user,
        uint256 amount,
        uint256 interval,
        uint256 nextCharge
    );
    event SubscriptionCancelled(address indexed user);
    event SubscriptionCharged(
        address indexed user,
        uint256 amount,
        uint256 nextCharge
    );

    error SubscriptionInactive(address user);
    error NotTimeForCharge(address user, uint256 nextCharge);
    error NotPermittedToken(address user, address token);
    error PermitInvalid(address user);

    struct Subscription {
        uint256 amount;
        uint256 interval;
        uint256 nextCharge;
        address token;
        bool active;
        bool firstChargeCompleted;
    }

    mapping(address => Subscription) public subs;

    function createSubscription(
        address user,
        address token,
        uint256 amount,
        uint256 interval,
        uint256 nextCharge
    ) external onlyOwner {
        Subscription storage s = subs[user];
        s.amount = amount;
        s.interval = interval;
        s.nextCharge = nextCharge;
        s.token = token;
        s.active = true;
        s.firstChargeCompleted = false;

        emit SubscriptionCreated(user, amount, interval, nextCharge);
    }

    function cancelSubscription(address user) external onlyOwner {
        subs[user].active = false;
        emit SubscriptionCancelled(user);
    }

    function cancelMySubscription() external {
        subs[msg.sender].active = false;
        emit SubscriptionCancelled(msg.sender);
    }

    function chargeSubscription(
        address user,
        bytes calldata permitData,
        bytes calldata signature
    ) external onlyOwner {
        Subscription storage s = subs[user];
        if (!s.active) revert SubscriptionInactive(user);
        if (block.timestamp < s.nextCharge)
            revert NotTimeForCharge(user, s.nextCharge);
        if (permitData.length == 0 || signature.length == 0)
            revert PermitInvalid(user);

        if (!s.firstChargeCompleted) {
            ISignatureTransfer.PermitTransferFrom memory permit = abi.decode(
                permitData,
                (ISignatureTransfer.PermitTransferFrom)
            );

            if (permit.permitted.token != s.token) revert();
            if (s.amount > permit.permitted.amount)
                revert NotPermittedToken(user, permit.permitted.token);
            if (permit.deadline < block.timestamp) revert PermitInvalid(user);

            ISignatureTransfer.SignatureTransferDetails memory transferDetails;
            transferDetails.to = treasury;
            transferDetails.requestedAmount = s.amount;

            ISignatureTransfer(address(permit2)).permitTransferFrom(
                permit,
                transferDetails,
                user,
                signature
            );

            s.firstChargeCompleted = true;
        } else {
            // FIX: new AllowanceTransfer API
            IAllowanceTransfer(address(permit2)).transferFrom(
                user,
                treasury,
                uint160(s.amount),
                s.token
            );
        }

        s.nextCharge += s.interval;

        emit SubscriptionCharged(user, s.amount, s.nextCharge);
    }

    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "zero addr");
        treasury = _treasury;
    }

    function getSubscription(
        address user
    ) external view returns (Subscription memory) {
        return subs[user];
    }
}
