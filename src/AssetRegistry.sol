// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IAsset} from "./IAsset.sol";
import {Asset} from "./Asset.sol";
import {IAssetRegistry} from "./IAssetRegistry.sol";

contract AssetRegistry is Ownable, IAssetRegistry {
    mapping(bytes32 => address) public assets;

    uint256 internal creatorFeeShare;
    uint256 internal registryFeeShare;
    uint256 internal totalFeeShare;

    error AssetAlreadyExists();
    error AssetNotFound();

    event AssetCreated(bytes32 indexed assetId, address indexed asset);

    constructor(uint256 _creatorFeeShare, uint256 _registryFeeShare) Ownable(msg.sender) {
        creatorFeeShare = _creatorFeeShare;
        registryFeeShare = _registryFeeShare;
        totalFeeShare = creatorFeeShare + registryFeeShare;
    }

    function createAsset(bytes32 _assetId, uint256 _subscriptionPrice, address _tokenAddress, address _owner) external onlyOwner returns (address)
    {

        if (assets[_assetId] != address(0)) {
            revert AssetAlreadyExists();    
        }

        Asset asset = new Asset(_assetId, _subscriptionPrice, _tokenAddress, _owner);
        assets[_assetId] = address(asset);

        emit AssetCreated(_assetId, address(asset));

        return address(asset);
    }

    function viewAsset(bytes32 _assetId) external view returns (bool)
    {
        return assets[_assetId] != address(0);
    }

    function getAsset(bytes32 _assetId) public view returns (address)
    {
        address asset = assets[_assetId];
        
        if (asset == address(0)) {
            revert AssetNotFound();
        }
        
        return asset;
    }

    function viewSubscription(bytes32 _assetId) external view returns (bool)
    {
        address asset = getAsset(_assetId);
        
        return IAsset(asset).viewSubscription(msg.sender);
    }

    function getSubscription(bytes32 _assetId) external view returns (uint256)
    {
        address asset = getAsset(_assetId);
        
        return IAsset(asset).getSubscription(msg.sender);
    }

    function getSubscriptionPrice(bytes32 _assetId, uint256 _duration) external view returns (uint256)
    {
        address asset = getAsset(_assetId);
        
        return IAsset(asset).getSubscriptionPrice(_duration);
    }

    function subscribe(bytes32 _assetId, address _owner, address _spender, uint256 _value, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) external returns (bool)
    {
        address asset = getAsset(_assetId);
        
        return IAsset(asset).subscribe(_owner, _spender, _value, _deadline, _v, _r, _s);
    }

    function updateCreatorFeeShare(uint256 _creatorFeeShare) external onlyOwner {
        creatorFeeShare = _creatorFeeShare;
        totalFeeShare = creatorFeeShare + registryFeeShare;
    }

    function updateRegistryFeeShare(uint256 _registryFeeShare) external onlyOwner {
        registryFeeShare = _registryFeeShare;
        totalFeeShare = creatorFeeShare + registryFeeShare;
    }

    function getCreatorFee(uint256 _value) external view returns (uint256) {
        return (_value * creatorFeeShare) / totalFeeShare;
    }

    function getRegistryFee(uint256 _value) external view returns (uint256) {
        return (_value * registryFeeShare) / totalFeeShare;
    }

    function getOwner() external view returns (address) {
        return this.owner();
    }
}