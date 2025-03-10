pragma solidity ^0.8.20;

interface IShortStakeContract {
    function isStaking(string calldata machineId) external view returns (bool);
}
