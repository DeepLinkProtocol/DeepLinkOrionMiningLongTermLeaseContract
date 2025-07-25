pragma solidity ^0.8.20;

interface IStakingContract {
    function isStaking(string calldata machineId) external view returns (bool);
    function rentMachine(string calldata machineId, uint256 rentFee) external;
    function endRentMachine(string calldata machineId) external;
    function renewRentMachine(string memory machineId, uint256 rentFee) external;
    function reportMachineFault(string calldata machineId, address renter) external;
    function getMachineInfo(string memory machineId)
        external
        view
        returns (
            address holder,
            uint256 calcPoint,
            uint256 startAtTimestamp,
            uint256 endAtTimestamp,
            uint256 nextRenterCanRentAt,
            uint256 reservedAmount
        );
    function getTotalGPUCountInStaking() external view returns (uint256);
    function getLeftGPUCountToStartReward() external view returns (uint256);
    function getGlobalState() external view returns (uint256, uint256, uint256);
    function joinStaking(string memory machineId, uint256 calcPoint, uint256 reserveAmount) external;

    function setBurnedRentFee(address _holder, string memory _machineId, uint256 fee) external;
    function addRentedGPUCount(address _holder, string memory _machineId) external;
    function getRewardDuration() external view returns (uint256);
}
