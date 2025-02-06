pragma solidity ^0.8.20;

import {NFTStaking} from "../NFTStaking.sol";

interface IDBCAIContract {
    function getMachineState(string calldata machineId, string calldata projectName, NFTStaking.StakingType stakingType)
        external
        view
        returns (bool isOnline, bool isRegistered);
}
