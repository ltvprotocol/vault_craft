# Vault Craft - Safe ERC-4626 LTV Vault Helpers

A collection of Solidity helper contracts that provide safe, slippage-protected operations for ERC-4626 tokenized vaults and collateral vaults.

### Safe ERC-4626 Helpers

Project provides the helper contracts that wrap ERC-4626 vault operations with built-in slippage protection and detailed error reporting:

- **Safe4626Helper**: For standard ERC-4626 vault operations with try/catch error handling and slippage protection
- **Safe4626CollateralHelper**: For collateral-specific ERC-4626 vault operations with try/catch error handling and slippage protection

### Flash Loan Helpers

Flash loan helpers that enable minting and redeeming LTV vault shares using flash loans, reducing the upfront capital requirements for users:

- **FlashLoanMintHelperWstethAndWeth**: Enables minting LTV vault shares using a flash loan. The helper:
  - Takes a flash loan of WETH from Morpho
  - Converts WETH to stETH and wraps it to wstETH
  - Uses wstETH as collateral (combining flash loan collateral with user-provided collateral)
  - Mints shares in the LTV vault via `executeLowLevelRebalanceShares`
  - Repays the flash loan
  - Allows users to mint shares with minimal upfront capital by leveraging the flash loan

- **FlashLoanRedeemHelperWstethAndWeth**: Enables redeeming LTV vault shares using a flash loan and Curve exchange. The helper:
  - Takes a flash loan of WETH from Morpho
  - Redeems shares from the LTV vault via `executeLowLevelRebalanceShares`
  - Unwraps wstETH collateral to stETH
  - Swaps stETH for ETH via Curve exchange
  - Wraps ETH to WETH
  - Repays the flash loan and sends remaining WETH to the user (if whitelisted)
  - Includes slippage protection for the Curve swap

## Deployed Addresses

### Mainnet

| Name | Address |
|------|---------|
| **Safe4626Helper** | [`0xb79baeb8eed4d53f040dfea46703812bbd0a1d9e`](https://etherscan.io/address/0xb79baeb8eed4d53f040dfea46703812bbd0a1d9e) |
| **Safe4626CollateralHelper** | [`0x25cd7dc2ffb7c453241a8c530e73c34bd642809c`](https://etherscan.io/address/0x25cd7dc2ffb7c453241a8c530e73c34bd642809c) |
| **FlashLoanMintHelperWstethAndWeth** | [`0x2f5636d96ed34cd9f3eb3ab5b657175a36408645`](https://etherscan.io/address/0x2f5636d96ed34cd9f3eb3ab5b657175a36408645) |
| **FlashLoanRedeemHelperWstethAndWeth** | [`0xa5836756b1d5db03dfccbafc4083a1e675a1f644`](https://etherscan.io/address/0xa5836756b1d5db03dfccbafc4083a1e675a1f644) |

### Sepolia

| Contract | Address |
|----------|---------|
| `Safe4626CollateralHelper` | [`0x25cd7dc2ffb7c453241a8c530e73c34bd642809c`](https://sepolia.etherscan.io/address/0x25cd7dc2ffb7c453241a8c530e73c34bd642809c) |
| `Safe4626Helper` | [`0xb79baeb8eed4d53f040dfea46703812bbd0a1d9e`](https://sepolia.etherscan.io/address/0xb79baeb8eed4d53f040dfea46703812bbd0a1d9e) |
| `GhostMintHelper` | [`0x169d36086e2a68062ed36bac5e0e733c5f0b872a`](https://sepolia.etherscan.io/address/0x169d36086e2a68062ed36bac5e0e733c5f0b872a) |
| `GhostRedeemHelper` | [`0x5f3eb9daef690364c2539b8148faa421b60427b2`](https://sepolia.etherscan.io/address/0x5f3eb9daef690364c2539b8148faa421b60427b2) |

## Security Audit

These contracts have undergone a security audit by Oxorio:

- **Oxorio**: [Vault Craft Security Audit Report](./audits/oxorio_vault_craft_security_audit.pdf)

## Links

- **Website**: [LTV](https://ltv.finance)
- **Protocol implementation**: [GitHub Repository](https://github.com/ltvprotocol/ltv_v0)
- **Documentation**: [Protocol Documentation](https://docs.ltv.finance)
- **Twitter**: [@ltvprotocol](https://x.com/ltvprotocol)