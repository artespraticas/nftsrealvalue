// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/AutoBounty.sol";

contract DeployAutoBounty is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address usdc = vm.envAddress("USDC_ADDRESS");

        vm.startBroadcast(deployerKey);

        AutoBounty bounty = new AutoBounty(usdc);

        vm.stopBroadcast();

        console2.log("AutoBounty deployed at:", address(bounty));
    }
}
