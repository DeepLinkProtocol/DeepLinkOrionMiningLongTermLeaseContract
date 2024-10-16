// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {NFTStaking} from "../src/NFTStaking.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";

import {console} from "forge-std/Test.sol";

contract Deploy is Script {
    function run() external returns (address proxy, address logic) {
        string memory privateKeyString = vm.envString("PRIVATE_KEY");
        uint256 deployerPrivateKey;

        if (
            bytes(privateKeyString).length > 0 && bytes(privateKeyString)[0] == "0" && bytes(privateKeyString)[1] == "x"
        ) {
            deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        } else {
            deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        }

        vm.startBroadcast(deployerPrivateKey);

        (proxy, logic) = deploy();
        vm.stopBroadcast();
        console.log("Proxy Contract deployed at:", proxy);
        console.log("Logic Contract deployed at:", logic);
        return (proxy, logic);
    }

    function deploy() public returns (address proxy, address logic) {
        Options memory opts;

        logic = Upgrades.deployImplementation("NFTStaking.sol:NFTStaking", opts);

        proxy = Upgrades.deployUUPSProxy(
            "NFTStaking.sol:NFTStaking",
            abi.encodeCall(
                NFTStaking.initialize,
                (
                    msg.sender,
                    address(0xfabDca15b28d8437C148EcC484817Fc28a85aDB8),
                    address(0x6e3c821b32950ABcf44bCE71c7f905a3cB960113),
                    address(0xb1ba8D79abecdDa60Fa2f19e7d8328A8602275a3),
                    address(0xb1BA8d79AbEcDDA60Fa2f19e7D8328a8602275A4),
                    1
                )
            )
        );
        return (proxy, logic);
    }
}
