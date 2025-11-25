# Permit2 Pull-Payment Subscription System  
![License: MIT](https://img.shields.io/badge/license-MIT-green)

## About
A lightweight recurring-payment system built on **Uniswap Permit2**, enabling gas-efficient subscription billing without requiring users to grant infinite allowances.

This repo focuses on the **core smart-contract logic**:
- The first charge uses a **signature-based permit**
- Recurring charges use **Permit2 stored allowances**
- Subscription state is on-chain; signatures are off-chain
- No custody, no token sweeping, minimal trust surface

The contract is intentionally simple to keep the logic auditable and minimal.

---

## Features
- Single-subscription model (per user)
- First-charge with `permitTransferFrom`
- Recurring charges with `transferFrom`
- Interval-based billing cycle
- Token-type stored per subscription
- Owner-restricted creation, charging, and cancellation
- Self-cancel functionality for users
- Configurable treasury address
- Clean separation between **on-chain billing logic** and **off-chain Permit2 signature creation**

---

## Quickstart

### Requirements
- Foundry (forge + cast)
- Solidity `0.8.17`
- Permit2 
- OpenZeppelin access-controls (local vendorized `oz/` folder)

---

### Installation

```bash
git clone https://github.com/yourname/Permit2-pull-payment-system.git
cd Permit2-pull-payment-system
forge install
