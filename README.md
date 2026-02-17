## Open Creator Rails

Open Creator Rails is a minimal, verifiable on-chain primitive for managing access to game resources using expiration-based entitlements. The system maps `[subject, resourceId] → expirationTime` to enable creator monetization use cases like an "on-chain Patreon."

The runtime plans to include a subscription engine, core registry and issuer contracts, Unity SDK integration (with a Demo), x402 settlement adapter, payment rails extensibility framework, high-performance verifier and indexer, abstract wallet linkage, and a creator's console (MCP based).

See the initial [MVP Architecture and Design](docs/mvp-design-and-architecture.md) document for a detailed flow diagrams and architecture specifications. This is for the MVP (Minimum Viable Product) or core on-chan implementation and doesn't reflect the intended final product.

---

## RPC API Reference

All external functions for the registry and asset contracts, for use with JSON-RPC (e.g. `eth_call` for reads, `eth_sendTransaction` for writes).

### IAssetRegistry

| Function | Type | Permissions | Description | Parameters |
|----------|------|-------------|-------------|------------|
| `createAsset(bytes32 _assetId, uint256 _subscriptionPrice, address _tokenAddress, address _owner)` | write | onlyOwner | Deploys a new Asset contract and registers it under the given id. | `_assetId` — Unique identifier for the asset.<br>`_subscriptionPrice` — Price per subscription unit for the asset.<br>`_tokenAddress` — ERC20 (with permit) used for subscription payments.<br>`_owner` — Creator/owner of the new asset. |
| `viewAsset(bytes32 _assetId)` | read | anyone | Checks whether an asset is registered for the given id. | `_assetId` — Asset identifier to check. |
| `getAsset(bytes32 _assetId)` | read | anyone | Returns the contract address of the asset for the given id. Throws if not found. | `_assetId` — Asset identifier to look up. |
| `viewSubscription(bytes32 _assetId)` | read | anyone | Checks whether the caller has an active subscription for the given asset. | `_assetId` — Asset identifier. |
| `viewSubscription(bytes32 _assetId, address _user)` | read | onlyOwner | Checks whether a user has an active subscription for the given asset. | `_assetId` — Asset identifier.<br>`_user` — User address. |
| `getSubscription(bytes32 _assetId)` | read | anyone | Returns the caller's subscription expiry timestamp for the given asset. | `_assetId` — Asset identifier. |
| `getSubscription(bytes32 _assetId, address _user)` | read | onlyOwner | Returns the subscription expiry timestamp for the given user for the given asset. | `_assetId` — Asset identifier.<br>`_user` — User address. |
| `getSubscriptionPrice(bytes32 _assetId, uint256 _duration)` | read | anyone | Returns the subscription price for the given asset and duration. | `_assetId` — Asset identifier.<br>`_duration` — Subscription duration in seconds. |
| `subscribe(bytes32 _assetId, address _owner, address _spender, uint256 _value, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s)` | write | anyone | Subscribes the given owner to the asset using ERC-2612 permit; forwards to the asset contract. | `_assetId` — Asset identifier.<br>`_owner` — Token owner and subscription beneficiary.<br>`_spender` — Must be the asset contract address for the permit.<br>`_value` — Permit allowance / payment amount.<br>`_deadline` — Permit signature expiry.<br>`_v` — Signature v.<br>`_r` — Signature r.<br>`_s` — Signature s. |
| `updateCreatorFeeShare(uint256 _creatorFeeShare)` | write | onlyOwner | Updates the creator's share of subscription fees. | `_creatorFeeShare` — New creator fee share (used with totalFeeShare for percentage). |
| `updateRegistryFeeShare(uint256 _registryFeeShare)` | write | onlyOwner | Updates the registry's share of subscription fees. | `_registryFeeShare` — New registry fee share (used with totalFeeShare for percentage). |
| `getCreatorFee(uint256 _value)` | read | anyone | Computes the creator portion of a payment value based on current fee shares. | `_value` — Total payment value. |
| `getRegistryFee(uint256 _value)` | read | anyone | Computes the registry portion of a payment value based on current fee shares. | `_value` — Total payment value. |
| `getOwner()` | read | anyone | Returns the owner of the registry (e.g. for receiving registry fees). | — |

---

### IAsset

| Function | Type | Permissions | Description | Parameters |
|----------|------|-------------|-------------|------------|
| `getAssetId()` | read | anyone | Returns the unique identifier for this asset. | — |
| `getSubscriptionPrice(uint256 duration)` | read | anyone | Returns the total price for a subscription of the given duration. | `duration` — Length of the subscription in seconds. |
| `setSubscriptionPrice(uint256 newSubscriptionPrice)` | write | onlyOwner | Sets the subscription price for the asset. | `newSubscriptionPrice` — New subscription price. |
| `getMySubscription()` | read | anyone | Returns the caller's current subscription expiry timestamp. | — |
| `getSubscription(address user)` | read | onlyRegistryOrOwner | Returns a user's subscription expiry timestamp. | `user` — Address to query. |
| `viewMySubscription()` | read | anyone | Checks whether the caller has an active subscription (expiry > block.timestamp). | — |
| `viewSubscription(address user)` | read | onlyRegistryOrOwner | Checks whether a user has an active subscription. | `user` — Address to check. |
| `subscribe(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)` | write | anyone | Subscribes an owner using ERC-2612 permit: owner signs permit, then payment is pulled and subscription extended. | `owner` — Token owner and subscription beneficiary.<br>`spender` — Must be this asset contract for the permit to be accepted.<br>`value` — Permit allowance / payment amount (will be rounded down to subscription price units).<br>`deadline` — Permit signature expiry.<br>`v` — Signature recovery id.<br>`r` — Signature r.<br>`s` — Signature s. |
| `revokeSubscription(address user)` | write | onlyOwner | Revokes a user's subscription. | `user` — Address whose subscription to revoke. |