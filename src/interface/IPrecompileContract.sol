// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPrecompileContract {
    function getMachineCalcPoint(string memory machineId) external view returns (uint256 calcPoint);

    function getMachineGPUCount(string memory machineId) external view returns (uint8);

    function getRentEndAt(uint256 rentId) external view returns (uint256);

    function getDlcMachineRentFee(string calldata machineId, uint256 rentBlockNumbers, uint8 rentGpuNumbers)
        external
        view
        returns (uint256);

    function isMachineOwner(address owner) external view returns (bool);
    //
    //GetMachineCalcPoint = "getMachineCalcPoint(string)",
    //GetMachineGPUCount = "getMachineGPUCount(string)",
    //GetRentEndAt = "getRentEndAt(string,uint256)",

    // ..

    function getRentingDuration(string memory machineId, uint256 rentId) external view returns (uint256 duration);

    function getRentDuration(uint256 lastClaimAt, uint256 slashClaimAt, uint256 endAt, string memory machineId)
        external
        view
        returns (uint256 rentDuration);

    function getDlcMachineRentDuration(uint256 lastClaimAt, uint256 slashAt, string memory machineId)
        external
        view
        returns (uint256 rentDuration);

    function getDlcMachineSlashedAt(string memory machineId) external view returns (uint256);

    function getDlcMachineSlashedReportId(string memory machineId) external view returns (uint256);

    function getDlcMachineSlashedReporter(string memory machineId) external view returns (address);

    function isSlashed(string memory machineId) external view returns (bool slashed);

    function reportDlcNftStaking(
        string memory msgToSign,
        string memory substrateSig,
        string memory substratePubKey,
        string memory machineId,
        uint256 phaseLevel
    ) external returns (bool success);
    function reportDlcNftEndStaking(
        string memory msgToSign,
        string memory substrateSig,
        string memory substratePubKey,
        string memory machineId,
        uint256 phaseLevel
    ) external returns (bool success);
    function getValidRewardDuration(uint256 lastClaimAt, uint256 totalStakeDuration, uint256 phaseLevel)
        external
        view
        returns (uint256 validDuration);
    function getDlcNftStakingRewardStartAt(uint256 phaseLevel) external view returns (uint256);

    function getDlcStakingGPUCount(uint256 phaseLevel) external view returns (uint256, uint256);

    function getRentedGPUCountInDlcNftStaking(uint256 phaseLevel) external view returns (uint256);

    function getRentedGPUCountOfMachineInDlcNftStaking(uint256 phaseLevel, string memory machineId)
        external
        view
        returns (uint256);

    function getTotalDlcNftStakingBurnedRentFee(uint256 phaseLevel) external view returns (uint256);

    function getDlcNftStakingBurnedRentFeeByMachine(uint256 phaseLevel, string memory machineId)
        external
        view
        returns (uint256);
}
