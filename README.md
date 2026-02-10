# Logistics Smart Contract

Sui Move smart contracts untuk logistics platform.

## Modules

- **`delivery_proof`** — Proof of Delivery NFT, menyimpan bukti pengiriman immutable on-chain  
- **`escrow`** — Payment Escrow untuk COD (Cash on Delivery), menahan pembayaran sampai delivery confirmed

## Deployment Info

- **Network**: Testnet
- **Package ID**: `0xf5bc9afb3c6342e3a6208a08681402074e9a3b89345760a92c8fe9931aa80380`
- **Explorer**: [View on SuiScan](https://suiscan.xyz/testnet/tx/DGTYsG3nHyRe7feUFNCic2yP7SJtb49mh1RLEYRAqtze)

## Build & Deploy

```bash
cd blockchain

# Build
sui move build

# Test
sui move test

# Deploy to testnet
sui client publish --gas-budget 100000000
```

## Project Structure

```
logistics-contract/
├── README.md
└── blockchain/
    ├── Move.toml
    ├── Move.lock
    ├── Published.toml
    ├── .env
    ├── sources/
    │   ├── delivery_proof.move
    │   └── escrow.move
    └── build/
```
