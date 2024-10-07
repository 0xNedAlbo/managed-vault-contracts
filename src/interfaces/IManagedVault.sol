// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC4626Upgradeable } from "@openzeppelin-upgradeable/contracts/interfaces/IERC4626Upgradeable.sol";

interface IManagedVault is IERC4626Upgradeable {
    function initialize(address manager_, address asset_, string memory name_, string memory symbol_) external;

    function setManager(address newManager_) external;

    function isShareholder(address address_) external view returns (bool);

    function addShareholder(address address_) external;

    function removeShareholder(address address_) external;

    function useAssets(address receiver_, uint256 amount_) external;

    function returnAssets(address sender_, uint256 amount_) external;

    function gains(uint256 amount_) external;

    function loss(uint256 amount_) external;

    function fees(uint256 amount_) external;

    function setAssetsInUse(uint256 amount_) external;

    /*function totalAssets() external view returns (uint256);

    function maxWithdraw(address address_) external view returns (uint256);

    function maxRedeem(address owner_) external view returns (uint256);

    function mint(uint256 shares, address receiver) external returns (uint256);

    function deposit(uint256 assets, address receiver) external returns (uint256);

    function redeem(uint256 shares, address receiver, address owner) external returns (uint256);

    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);*/
}
