pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {MockUSDC} from "../src/MockUSDC.sol";
import {ViFiDAO} from "../src/ViFiDAO.sol";
import {Virtualizer} from "../src/Virtualizer.sol";
import {vToken} from "../src/vToken.sol";

contract DeployViFi is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address chainlinkrouter = 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0;
        bytes32 donid = 0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000;

        vm.startBroadcast(deployerPrivateKey);

        MockUSDC mUSDC = new MockUSDC();
        ViFiDAO dao = new ViFiDAO(address(mUSDC), chainlinkrouter, donid);

        console.log("MockUSDC contract address:", address(mUSDC));
        console.log("ViFiDAO contract address:", address(dao));

        vm.stopBroadcast();
    }
}
