// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IStateContract {
    function getMachinesInStaking(uint256 page, uint256 pageSize) external view returns (string[] memory);

    function addReserveAmount(address _holder, string memory _machineId, uint256 _reserveAmount) external;

    function addOrUpdateStakeHolder(
        address _holder,
        string memory _machineId,
        uint256 _calcPoint,
        uint8 _gpuCount,
        bool isAdd
    ) external;

    function removeMachine(address _holder, string memory _machineId) external;

    function setBurnedRentFee(address _holder, string memory _machineId, uint256 fee) external;

    function addRentedGPUCount(address _holder, string memory _machineId, uint8 rentedGPUCount) external;

    function subRentedGPUCount(address _holder, string memory _machineId) external;

    function subReserveAmount(address _holder, string memory _machineId, uint256 _reserveAmount) external;

    function addClaimedRewardAmount(
        address _holder,
        string memory _machineId,
        uint256 totalClaimedAmount,
        uint256 releasedAmount
    ) external;
}
