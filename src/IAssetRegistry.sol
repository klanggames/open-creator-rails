// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAssetRegistry {
    function createAsset(bytes32 _assetId, uint256 _subscriptionPrice, address _tokenAddress, address _owner) external returns (address);
    
    function viewAsset(bytes32 _assetId) external view returns (bool);
    
    function getAsset(bytes32 _assetId) external view returns (address);
    
    function viewSubscription(bytes32 _assetId) external view returns (bool);
    
    function getSubscription(bytes32 _assetId) external view returns (uint256);
    
    function getSubscriptionPrice(bytes32 _assetId, uint256 _duration) external view returns (uint256);

    function subscribe(bytes32 _assetId, address _owner, address _spender, uint256 _value, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) external returns (bool);
    
    function updateCreatorFeeShare(uint256 _creatorFeeShare) external;
    
    function updateRegistryFeeShare(uint256 _registryFeeShare) external;
    
    function getCreatorFee(uint256 _value) external view returns (uint256);

    function getRegistryFee(uint256 _value) external view returns (uint256);

    function getOwner() external view returns (address);
}