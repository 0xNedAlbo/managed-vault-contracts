// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {
    ERC4626Upgradeable,
    IERC4626Upgradeable,
    IERC20Upgradeable
} from "@openzeppelin-upgradeable/contracts/token/ERC20/extensions/ERC4626Upgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/extensions/ERC4626Upgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { MathUpgradeable } from "@openzeppelin-upgradeable/contracts/utils/math/MathUpgradeable.sol";
import { IManagedVault } from "./interfaces/IManagedVault.sol";

contract ManagedVault is ERC4626Upgradeable, IManagedVault {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    address public manager;

    mapping(address => bool) public shareholders;
    mapping(address => bool) public keepers;

    uint256 public assetsInUse;

    modifier onlyManager() {
        require(msg.sender == manager, "ManagedVault: Only allowed for manager");
        _;
    }

    modifier onlyManagerOrKeeper() {
        require(keepers[msg.sender] || msg.sender == manager, "ManagedVault: only allowed for keepers or manager");
        _;
    }

    event AddShareholder(address indexed newShareholder);
    event RemoveShareholder(address indexed removedShareholder);

    event AddKeeper(address indexed newKeeper);
    event RemoveKeeper(address indexed removedKeeper);

    event ChangeManager(address indexed newManager);

    event UseAssets(address indexed receiver, uint256 amount);
    event ReturnAssets(address indexed sender, uint256 amount);
    event Gains(uint256 amount);
    event Loss(uint256 amount);
    event Fees(uint256 amount);

    function initialize(
        address manager_,
        address asset_,
        string memory name_,
        string memory symbol_
    )
        public
        virtual
        override
        initializer
    {
        manager = manager_;
        __ERC20_init(name_, symbol_);
        __ERC4626_init(IERC20Upgradeable(asset_));
    }

    function setManager(address newManager_) public virtual override onlyManager {
        require(newManager_ != address(0), "ManagedVault: Manager cannot be null");
        require(!isShareholder(newManager_), "ManagedVault: Shareholder cannot be manager");
        emit ChangeManager(newManager_);
        manager = newManager_;
    }

    function isShareholder(address address_) public view virtual override returns (bool) {
        return shareholders[address_];
    }

    function addShareholder(address address_) public virtual override onlyManager {
        require(address_ != address(0), "ManagedVault: Shareholder cannot be null");
        require(address_ != manager, "ManagedVault: Manager cannot be shareholder");
        if (!shareholders[address_]) emit AddShareholder(address_);
        shareholders[address_] = true;
    }

    function removeShareholder(address address_) public virtual override onlyManager {
        if (shareholders[address_]) emit RemoveShareholder(address_);
        shareholders[address_] = false;
    }

    function useAssets(address receiver_, uint256 amount_) public virtual override onlyManagerOrKeeper {
        IERC20Upgradeable(asset()).safeTransfer(receiver_, amount_);
        assetsInUse += amount_;
        emit UseAssets(receiver_, amount_);
    }

    function returnAssets(address sender_, uint256 amount_) public virtual override onlyManagerOrKeeper {
        IERC20Upgradeable(asset()).safeTransferFrom(sender_, address(this), amount_);
        emit ReturnAssets(sender_, amount_);
        if (amount_ > assetsInUse) {
            emit Gains(amount_ - assetsInUse);
            assetsInUse = 0;
        } else {
            assetsInUse -= amount_;
        }
    }

    function gains(uint256 amount_) public virtual override onlyManagerOrKeeper {
        _gains(amount_);
    }

    function _gains(uint256 amount_) internal virtual {
        assetsInUse += amount_;
        emit Gains(amount_);
    }

    function loss(uint256 amount_) public virtual override onlyManagerOrKeeper {
        _loss(amount_);
    }

    function _loss(uint256 amount_) internal virtual onlyManagerOrKeeper {
        require(amount_ <= assetsInUse, "ManagedVault: Loss cannot be higher than assets in use");
        assetsInUse -= amount_;
        emit Loss(amount_);
    }

    function fees(uint256 amount_) public virtual override onlyManagerOrKeeper {
        _fees(amount_);
    }

    function _fees(uint256 amount_) internal virtual onlyManagerOrKeeper {
        require(amount_ <= assetsInUse, "ManagedVault: Fees cannot be higher than assets in use");
        assetsInUse -= amount_;
        emit Fees(amount_);
    }

    function setAssetsInUse(uint256 amount_) public virtual override onlyManagerOrKeeper {
        _setAssetsInUse(amount_);
    }

    function _setAssetsInUse(uint256 amount_) internal virtual onlyManagerOrKeeper {
        if (amount_ > assetsInUse) _gains(amount_ - assetsInUse);
        else if (amount_ < assetsInUse) _loss(assetsInUse - amount_);
    }

    function totalAssets() public view virtual override(ERC4626Upgradeable, IERC4626Upgradeable) returns (uint256) {
        return IERC20Upgradeable(asset()).balanceOf(address(this)) + assetsInUse;
    }

    function maxWithdraw(
        address address_
    )
        public
        view
        virtual
        override(ERC4626Upgradeable, IERC4626Upgradeable)
        returns (uint256)
    {
        uint256 shares = balanceOf(address_);
        uint256 assets = _convertToAssets(shares, MathUpgradeable.Rounding.Down);
        uint256 vaultBalance = IERC20Upgradeable(asset()).balanceOf(address(this));
        return MathUpgradeable.min(assets, vaultBalance);
    }

    function maxRedeem(
        address owner_
    )
        public
        view
        virtual
        override(ERC4626Upgradeable, IERC4626Upgradeable)
        returns (uint256)
    {
        uint256 maxAssets = maxWithdraw(owner_);
        return _convertToShares(maxAssets, MathUpgradeable.Rounding.Down);
    }

    function mint(
        uint256 shares,
        address receiver
    )
        public
        virtual
        override(ERC4626Upgradeable, IERC4626Upgradeable)
        returns (uint256)
    {
        require(isShareholder(receiver), "ManagedVault: Receiver is not a whitelisted shareholder");
        return ERC4626Upgradeable.mint(shares, receiver);
    }

    function deposit(
        uint256 assets,
        address receiver
    )
        public
        virtual
        override(ERC4626Upgradeable, IERC4626Upgradeable)
        returns (uint256)
    {
        require(isShareholder(receiver), "ManagedVault: Receiver is not a whitelisted shareholder");
        return ERC4626Upgradeable.deposit(assets, receiver);
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    )
        public
        virtual
        override(ERC4626Upgradeable, IERC4626Upgradeable)
        returns (uint256)
    {
        return ERC4626Upgradeable.redeem(shares, receiver, owner);
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    )
        public
        virtual
        override(ERC4626Upgradeable, IERC4626Upgradeable)
        returns (uint256)
    {
        return ERC4626Upgradeable.withdraw(assets, receiver, owner);
    }
}
