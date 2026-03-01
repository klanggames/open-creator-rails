// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAsset} from "./IAsset.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20Permit} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IAssetRegistry} from "./IAssetRegistry.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

/// @title Asset
/// @notice Implementation of IAsset: a subscription-gated asset with permit-based ERC20 payment.
///         Deployed by the asset registry; subscription revenue is split between creator (owner) and registry.
contract Asset is Ownable, ReentrancyGuard, IAsset {
    bytes32 internal immutable ASSET_ID;
    address internal immutable REGISTRY_ADDRESS;

    IAssetRegistry internal immutable ASSET_REGISTRY;

    address internal immutable TOKEN_ADDRESS;
    IERC20 internal immutable TOKEN_CONTRACT;
    IERC20Permit internal immutable TOKEN_PERMIT_CONTRACT;

    mapping(address => uint256) internal subscriptions;
    uint256 internal subscriptionPrice;

    error InvalidOwner();
    error InvalidTokenAddress();
    error InvalidSpender();
    error PermitFailed();
    error SubscriptionFailed();
    error InsufficientFunds();
    error OnlyRegistryOrOwnerUnauthorizedAccount();

    event SubscriptionAdded(address indexed user, uint256 expiresAt);
    event SubscriptionPriceUpdated(uint256 newSubscriptionPrice);
    event SubscriptionRevoked(address indexed user);

    /// @notice Initializes the asset with id, price, payment token, and owner. Callable only by the registry (msg.sender).
    /// @param _assetId Unique identifier for this asset.
    /// @param _subscriptionPrice Price per subscription period in seconds.
    /// @param _tokenAddress ERC20 (with permit) used for subscription payments.
    /// @param _owner Creator/owner of the asset; receives creator share of subscription fees.
    constructor(bytes32 _assetId, uint256 _subscriptionPrice, address _tokenAddress, address _owner) Ownable(_owner) {
        ASSET_ID = _assetId;
        subscriptionPrice = _subscriptionPrice;

        if (_owner == address(0)) {
            revert InvalidOwner();
        }

        if (_tokenAddress == address(0)) {
            revert InvalidTokenAddress();
        }

        TOKEN_ADDRESS = _tokenAddress;

        TOKEN_CONTRACT = IERC20(TOKEN_ADDRESS);
        TOKEN_PERMIT_CONTRACT = IERC20Permit(TOKEN_ADDRESS);

        REGISTRY_ADDRESS = msg.sender;
        ASSET_REGISTRY = IAssetRegistry(REGISTRY_ADDRESS);
    }

    function getAssetId() external view returns (bytes32) {
        return ASSET_ID;
    }

    function getRegistryAddress() external view returns (address) {
        return REGISTRY_ADDRESS;
    }

    function getTokenAddress() external view returns (address) {
        return TOKEN_ADDRESS;
    }

    function setSubscriptionPrice(uint256 newSubscriptionPrice) external onlyOwner {
        subscriptionPrice = newSubscriptionPrice;
        emit SubscriptionPriceUpdated(newSubscriptionPrice);
    }

    function getSubscriptionPrice(uint256 duration) external view returns (uint256) {
        return subscriptionPrice * duration;
    }

    function getMySubscription() external view returns (uint256) {
        return subscriptions[msg.sender];
    }

    function getSubscription(address user) external onlyRegistryOrOwner view returns (uint256) {
        
        return subscriptions[user];
    }

    function viewMySubscription() external view returns (bool) {
        return subscriptions[msg.sender] > block.timestamp;
    }

    function viewSubscription(address user) external onlyRegistryOrOwner view returns (bool) {
        
        return subscriptions[user] > block.timestamp;
    }

    function subscribe(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external nonReentrant returns (uint256) {

        if (spender != address(this)) {
            revert InvalidSpender();
        }
        
        try TOKEN_PERMIT_CONTRACT.permit(owner, address(this), value, deadline, v, r, s) {
            
            value -= value % subscriptionPrice;

            if (value < subscriptionPrice) {
                revert InsufficientFunds();
            }

            (uint256 creatorFee, uint256 registryFee) = ASSET_REGISTRY.getFees(value);

            bool success = TOKEN_CONTRACT.transferFrom(owner, this.owner(), creatorFee) && TOKEN_CONTRACT.transferFrom(owner, ASSET_REGISTRY.getOwner(), registryFee);

            if (!success) {
                revert SubscriptionFailed();
            }
        }
        catch {
            revert PermitFailed();
        }

        uint256 duration = value / subscriptionPrice;

        uint256 subscription = subscriptions[owner] > block.timestamp ? subscriptions[owner] : block.timestamp;

         subscription += duration;

         subscriptions[owner] = subscription;

        emit SubscriptionAdded(owner, subscription);

        return subscription;
    }

    function revokeSubscription(address user) external onlyOwner returns (bool) {
        uint256 duration = subscriptions[user];
        if (duration == 0) {
            return false;
        }
        delete subscriptions[user];
        emit SubscriptionRevoked(user);
        return true;
    }

    modifier onlyRegistryOrOwner() {
        _onlyRegistryOrOwner();
        _;
    }
    
    function _onlyRegistryOrOwner() internal view {
         if (msg.sender != REGISTRY_ADDRESS && msg.sender != owner()) {
             revert OnlyRegistryOrOwnerUnauthorizedAccount();
         }
     }
}