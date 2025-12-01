# Permit2 Pull-Payment Subscription System  
[![Foundry](https://img.shields.io/badge/Built%20With-Foundry-blue)](https://book.getfoundry.sh/)  
[![Solidity](https://img.shields.io/badge/Solidity-0.8.25-black)](https://github.com/ethereum/solidity)  
[![Uniswap Permit2](https://img.shields.io/badge/Powered%20By-Uniswap%20Permit2-purple)](https://github.com/Uniswap/permit2)

---

## About

This project implements a **real-world subscription billing system** using **Uniswap's Permit2** standard.  
Subscribers authorize the *first* payment using an EIP-712 signature (PermitTransferFrom), and all **recurring charges** use Permit2’s gas-efficient **AllowanceTransfer**.

The goal is a fully functional pull-payment primitive that mirrors how Stripe/PayPal subscriptions work — but entirely on-chain.

This repo includes:

- A verified deployment on **Sepolia**  
- A working **EIP-712 signing mini frontend (signer.html)**  
- A **SubscriptionManager** contract controlling billing logic  
- A **TestToken** ERC-20 for testing charges  
- Full Foundry deployment scripts  
- End-to-end successful payment execution  

---

## Features

- **Permit2 First-Charge Flow**  
  - User signs once using PermitTransferFrom (EIP-712 typed data)  
  - Owner triggers the first charge without any pre-approval  

- **Recurring Subscription Charges**  
  - Follow-up charges use AllowanceTransfer for low gas and safety  
  - Requires a single user approval for Permit2  

- **Configurable Subscription Parameters**  
  - amount  
  - interval (in seconds)  
  - token  
  - nextCharge timestamp  
  - active/inactive state  
  - firstChargeCompleted flag  

- **Event Log Tracking**  
  - SubscriptionCreated  
  - SubscriptionCharged  
  - SubscriptionCancelled  

- **Mini Permit Signer Frontend**  
  - Two-button UI (Connect + Sign EIP-712)  
  - Fully local, served from `localhost`  
  - Creates valid Permit2 signatures for the first charge  

- **Complete Sepolia Deployment**  
  - Contract verified  
  - Tested live with successful transfers  

---

## Quickstart

### Requirements

- Foundry  
- Node.js (optional for frontend)  
- MetaMask  
- A Sepolia RPC (Alchemy recommended)

### Installation

```bash
git clone https://github.com/Alpy16/Permit2-pull-payment-system.git
cd Permit2-pull-payment-system
forge install
```

### Environment Setup

Create `.env`:

```
SEPOLIA_RPC="https://sepolia.g.alchemy.com/v2/YOUR_KEY"
PRIVATE_KEY="YOUR_DEPLOYER_PRIVATE_KEY"
```

Load environment:

```bash
source .env
```

---

## Usage

### Build Contracts

```bash
forge build
```

### Run Tests

```bash
forge test -vvv
```

### Deploy to Sepolia

```bash
forge script script/DeploySubscriptionManager.s.sol:DeploySubscriptionManager \
  --rpc-url $SEPOLIA_RPC \
  --private-key $PRIVATE_KEY \
  --broadcast
```

### Deploy TestToken

```bash
forge script script/DeployTestToken.s.sol:DeployTestToken \
  --rpc-url $SEPOLIA_RPC \
  --private-key $PRIVATE_KEY \
  --broadcast
```

### Verify Contract on Etherscan

```bash
forge verify-contract \
  --chain sepolia \
  --etherscan-api-key $ETHERSCAN_KEY \
  --num-of-optimizations 200 \
  <contract_address> \
  src/SubscriptionManager.sol:SubscriptionManager
```

---

## EIP-712 Signing Frontend (signer.html)

Serve locally:

```bash
python3 -m http.server 8000
```

Open:

```
http://localhost:8000/signer.html
```

Use:

- **Connect Wallet**  
- **Paste typed data**  
- **Sign Typed Data (v4)**  

The resulting signature is used in:

```
chargeSubscription(user, permitData, signature)
```

---

## Project Structure

```
Permit2-pull-payment-system/
│
├── src/
│   ├── SubscriptionManager.sol      # Main contract
│   └── TestToken.sol                # Simple ERC-20 for testing
│
├── script/
│   ├── DeploySubscriptionManager.s.sol
│   └── DeployTestToken.s.sol
│
├── signer.html                      # Minimal EIP-712 frontend
│
├── broadcast/                       # Deployment artifacts
│
├── test/                            # (Optional) add fuzz/invariant tests
│
└── foundry.toml
```

---

## License

MIT License.  


