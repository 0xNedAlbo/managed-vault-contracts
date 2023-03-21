// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../mocks/MockERC20.sol";

import "../../src/vaults/ManagedVaultFactory.sol";
import "../../src/vaults/ManagedVault.sol";

contract ManagedSwapFactoryTest is Test {
    ManagedVault vault;
    ManagedVaultFactory factory;

    MockERC20 asset;

    address deployer;
    address alice;

    function setUp() public {
        deployer = makeAddr("deployer");
        alice = makeAddr("alice");

        asset = new MockERC20("Token A", "TOKA");

        vm.startPrank(deployer);
        vault = new ManagedVault();
        factory = new ManagedVaultFactory(address(vault));
    }

    function test_Create_Vault() public {
        address proxy = factory.create(deployer, address(asset), "Test Vault", "VAULT");
        vm.stopPrank();
        assertTrue(proxy != address(0));
        assertEq(ManagedVault(proxy).name(), "Test Vault", "Vault name does not match");
        assertEq(ManagedVault(proxy).symbol(), "VAULT", "Vault symbol does not match");
        assertEq(ManagedVault(proxy).asset(), address(asset), "Token address does not match");
    }
}
