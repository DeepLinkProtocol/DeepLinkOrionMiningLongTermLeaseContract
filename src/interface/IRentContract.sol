pragma solidity ^0.8.20;

interface IRentContract {
    function getBurnedRentFeeByStakeholder(uint8 phaseLevel, address stakeholder) external view returns (uint256);

    function getRentedGPUCountOfStakeHolder(uint8 phaseLevel, address stakeHolder) external view returns (uint256);

    function getTotalBurnedRentFee(uint8 phaseLevel) external view returns (uint256);

    function getTotalRentedGPUCount(uint256 phaseLevel) external view returns (uint256);

    function isRented(string calldata machineId)  view external returns (bool);
}
