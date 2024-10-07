// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../lib/forge-std/src/Script.sol";
import "../lib/mock-tokens/src/MockERC20.sol";
import "../src/ManagedVault.sol";
import "../src/ManagedVaultFactory.sol";

contract DeployLocal is Script {
    function run() public {
        vm.startBroadcast(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80);

        MockERC20 dai = new MockERC20("DAI Stablecoin (DAI)", "DAI", 18);
        dai.mint(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, 10_000 ether);
        dai.mint(0x70997970C51812dc3A010C7d01b50e0d17dc79C8, 10_000 ether);
        dai.mint(0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC, 10_000 ether);
        address vaultTemplate = address(new ManagedVault());
        ManagedVaultFactory factory = new ManagedVaultFactory(vaultTemplate);
        address vault =
            factory.create(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, address(dai), "Managed Test Vault", "SHARES");

        console.log("Mock DAI deployed at ", address(dai));
        console.log("ManagedVaultFactory deployed at ", address(factory));
        console.log("ManagedVault deployed at ", vault);

        vm.stopBroadcast();
    }
}
