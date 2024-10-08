// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/utils/math/Math.sol";

import "@mock-tokens/MockERC20.sol";
import "../utils/ManagedVaultUtils.sol";

contract ManagedVaultTest is ManagedVaultUtils {
    using Math for uint256;

    function setUp() public {
        reset_Vault();
    }

    function test_Vault_Lifecycle() public {
        save_state();
        // Check deposit previews.
        assertEq(vault.previewDeposit(100 ether), 100 ether, "Depositing 100 tokens does not result in 100 shares");

        // Bob invests 100 asset tokens
        bob_invests_assets(100 ether);
        assertEq(asset.balanceOf(bob), bobsAssetBalance - 100 ether, "Bob has not paid 100 asset tokens");
        assertEq(asset.balanceOf(address(vault)), 100 ether, "Vault has not received 100 asset tokens");

        // Alice uses 55 tokens from the vault
        alice_uses_assets(55 ether);
        assertEq(asset.balanceOf(alice), alicesAssetBalance + 55 ether, "Alice has not received 100 asset tokens");
        assertEq(asset.balanceOf(address(vault)), 45 ether, "Vault has not spent 100 asset tokens");
        assertEq(vault.assetsInUse(), 55 ether, "Vault assets in use is not 55 asset tokens");
        assertEq(vault.totalAssets(), 100 ether, "Total assets in vault are not 100 ether");
        assertEq(vault.convertToAssets(vault.balanceOf(bob)), 100 ether, "Assets of Bob are not 100 asset tokens");

        // Alice takes a fee of 5 tokens
        alice_charges_fees(5 ether);
        assertEq(vault.assetsInUse(), 50 ether, "Fee is not removed from assets in use");
        assertEq(vault.totalAssets(), 95 ether, "Fee is not removed from vault total assets");
        assertEq(vault.convertToAssets(vault.balanceOf(bob)), 95 ether, "Fee is not removed from Bob's shares");
        assertEq(vault.maxWithdraw(bob), 45 ether, "Bob's withdrawable funds are not 45 ether");
        // 45 tokens * 100 shares / 95 tokens
        assertEq(
            vault.maxRedeem(bob),
            uint256(45 ether).mulDiv(100 ether, 95 ether),
            "Bob's redeemable shares are not 45 ether"
        );

        // Bob withdraws 20 asset tokens
        uint256 sharesToBurn = uint256(20 ether).mulDiv(100 ether, 95 ether, Math.Rounding.Up);
        assertEq(vault.previewWithdraw(20 ether), sharesToBurn);
        bob_withdraws_assets(20 ether);
        assertEq(asset.balanceOf(bob), bobsAssetBalance - 100 ether + 20 ether, "Bob did not receive 20 ether");
        assertEq(vault.balanceOf(bob), 100 ether - sharesToBurn, "Bob did not burn the correct amount of shares");

        save_state();

        // Bob buys 60 more shares
        uint256 assetsToPay = uint256(60 ether).mulDiv(vaultTotalAssets, vault.totalSupply(), Math.Rounding.Up);
        bob_buys_shares(60 ether);
        assertEq(asset.balanceOf(bob), bobsAssetBalance - assetsToPay, "Bob did not pay the correct amount of assets");
        assertEq(
            asset.balanceOf(address(vault)),
            vaultAssetBalance + assetsToPay,
            "Vault did not receive the correct anount of assets"
        );
        assertEq(
            vault.totalAssets(),
            vaultTotalAssets + assetsToPay,
            "Vault total assets did not increase by the correct amount"
        );
        assertEq(vault.totalSupply(), vaultTotalShares + 60 ether, "Vault shares have not increased by 60");
        assertEq(vault.balanceOf(bob), bobsShares + 60 ether, "Bobs shares have not increased by 60");

        // ...Save state...
        save_state();

        // Bob redeems 35 shares
        uint256 assetsToReceive = uint256(35 ether).mulDiv(vaultTotalAssets, vaultTotalShares, Math.Rounding.Down);
        bob_redeems_shares(35 ether);
        assertEq(
            asset.balanceOf(bob), bobsAssetBalance + assetsToReceive, "Bob did not receive the correct amount of tokens"
        );
        assertEq(
            asset.balanceOf(address(vault)),
            vaultAssetBalance - assetsToReceive,
            "Vault did not pay out correct amount of tokens"
        );
        assertEq(
            vault.totalAssets(),
            vaultTotalAssets - assetsToReceive,
            "Vault total assets did not decrease by the correct amount"
        );
        assertEq(vault.balanceOf(bob), bobsShares - 35 ether, "Bobs shares did not decrease by 35");
        assertEq(vault.totalSupply(), vaultTotalShares - 35 ether, "Vault shares did not decrease by 35");

        // ...Save state...
        save_state();

        // Alice returns assets to vault
        alice_returns_assets(50 ether);
        assertEq(
            asset.balanceOf(alice),
            alicesAssetBalance - 50 ether,
            "Alices asset balance did not decrease by returned amount"
        );
        assertEq(
            asset.balanceOf(address(vault)),
            vaultAssetBalance + 50 ether,
            "Vaults asset balance did not increase by returned amount"
        );

        // ...Save state...
        save_state();

        // Bob withdraws all remaining assets
        uint256 assetsToWithdraw = vault.convertToAssets(bobsShares);
        assertEq(assetsToWithdraw, vaultTotalAssets, "Bobs assets and vault assets are not equal");
        bob_withdraws_assets(assetsToWithdraw);
        assertEq(
            asset.balanceOf(bob),
            bobsAssetBalance + assetsToWithdraw,
            "Bob did not receive the correct amount of tokens"
        );
        assertEq(asset.balanceOf(address(vault)), 0 ether, "Vault is not empty");
        assertEq(vault.totalAssets(), 0, "Vault total assets is not null");
        assertEq(vault.totalSupply(), 0, "Vault total shares is not null");
        assertEq(vault.balanceOf(bob), 0, "Shares of bob should null");
    }

    function test_Whitelist() public {
        // ...Save state...
        save_state();

        // Revoke shareholder role of charles
        assertTrue(vault.isShareholder(charles), "Charles is no shareholder");
        vm.prank(alice);
        vault.removeShareholder(charles);
        assertFalse(vault.isShareholder(charles), "Charles is still shareholder");

        // Deposit and mint for someone not whitlisted
        assertFalse(vault.isShareholder(charles), "Charles should not be whitelisted");
        vm.startPrank(bob);
        vm.expectRevert(bytes("ManagedVault: Receiver is not a whitelisted shareholder"));

        vault.deposit(100 ether, charles);
        vm.expectRevert(bytes("ManagedVault: Receiver is not a whitelisted shareholder"));
        vault.mint(100 ether, charles);
    }

    event Gains(uint256 amount);
    event Loss(uint256 amount);

    function test_Gains_And_Losses() public {
        // ...Save state...
        bob_invests_assets(100 ether);
        save_state();
        vm.startPrank(alice);

        // Alice books some gains
        vm.expectEmit(false, false, false, true);
        emit ManagedVaultTest.Gains(10 ether);
        vault.gains(10 ether);
        assertEq(vault.assetsInUse(), vaultAssetsInUse + 10 ether, "Vault has not gained 10 tokens");

        // ...Save state...
        save_state();

        // Alice books some losses
        vm.expectEmit(false, false, false, true);
        emit ManagedVaultTest.Loss(5 ether);
        vault.loss(5 ether);
        assertEq(vault.assetsInUse(), vaultAssetsInUse - 5 ether, "Vault has not lost 5 tokens");
        vm.expectRevert(bytes("ManagedVault: Loss cannot be higher than assets in use"));
        vault.loss(10 ether);

        // ...Save state...
        save_state();

        // Alice changes assets in use
        vm.expectEmit(false, false, false, true);
        emit ManagedVaultTest.Gains(15 ether);
        vault.setAssetsInUse(20 ether);
        assertEq(vault.assetsInUse(), 20 ether, "Vault has not 20 tokens in use");

        // Check access rights.
        vm.stopPrank();
        vm.startPrank(bob);
        vm.expectRevert(bytes("ManagedVault: only allowed for keepers or manager"));
        vault.gains(10 ether);
        vm.expectRevert(bytes("ManagedVault: only allowed for keepers or manager"));
        vault.loss(10 ether);
        vm.expectRevert(bytes("ManagedVault: only allowed for keepers or manager"));
        vault.setAssetsInUse(10 ether);
    }

    function test_Use_and_Return_Assets() public {
        bob_invests_assets(100 ether);

        // ...Save state...
        save_state();

        vm.startPrank(alice);

        // Alice uses assets for herself
        vault.useAssets(alice, 50 ether);
        assertEq(
            asset.balanceOf(address(vault)),
            vaultAssetBalance - 50 ether,
            "Vault balance should be decreased by 50 ether"
        );
        assertEq(
            asset.balanceOf(alice),
            alicesAssetBalance + 50 ether,
            "Alice's asset balance should be increased by 50 ether"
        );
        assertEq(vault.assetsInUse(), 50 ether, "Assets in use should be 50 ether");

        // ...Save state...
        save_state();

        // Alice returns assets to vault
        vault.returnAssets(alice, 50 ether);
        assertEq(
            asset.balanceOf(address(vault)),
            vaultAssetBalance + 50 ether,
            "Vault balance should be increased by 50 ether"
        );
        assertEq(
            asset.balanceOf(alice),
            alicesAssetBalance - 50 ether,
            "Alice's asset balance should be decreased by 50 ether"
        );
        assertEq(vault.assetsInUse(), 0 ether, "Assets in use should be 0 ether");

        // ...Save state...
        save_state();

        // Alice uses assets for Charles
        vault.useAssets(charles, 50 ether);
        assertEq(
            asset.balanceOf(address(vault)),
            vaultAssetBalance - 50 ether,
            "Vault balance should be decreased by 50 ether"
        );
        assertEq(asset.balanceOf(alice), alicesAssetBalance, "Alice's asset balance should be unchanged");
        assertEq(
            asset.balanceOf(charles),
            charlesAssetBalance + 50 ether,
            "Charles' asset balance should be increased by 50 ether"
        );
        assertEq(vault.assetsInUse(), 50 ether, "Assets in use should be 50 ether");

        // ...Save state...
        save_state();

        // Alice returns assets from Charles without allowance
        vm.expectRevert();
        vault.returnAssets(charles, 50 ether);

        // Alice returns assets from Charles
        vm.stopPrank();
        vm.prank(charles);
        asset.approve(address(vault), 50 ether);
        vm.prank(alice);
        vault.returnAssets(charles, 50 ether);
        assertEq(
            asset.balanceOf(address(vault)),
            vaultAssetBalance + 50 ether,
            "Vault balance should be increased by 50 ether"
        );
        assertEq(asset.balanceOf(alice), alicesAssetBalance, "Alice's asset balance should be unchanged");
        assertEq(
            asset.balanceOf(charles),
            charlesAssetBalance - 50 ether,
            "Charles' asset balance should be decreased by 50 ether"
        );
        assertEq(vault.assetsInUse(), 0 ether, "Assets in use should be 0 ether");
    }
}
