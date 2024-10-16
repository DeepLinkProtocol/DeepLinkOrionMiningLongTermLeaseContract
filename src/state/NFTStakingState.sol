// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../interface/IPrecompileContract.sol";

/// @custom:oz-upgrades-from NFTStakingStateOld
contract NFTStakingState is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    IPrecompileContract public precompileContract;
    uint8 public phaseLevel;
    address public nftStakingAddress;

    struct MachineInfo {
        uint256 calcPoint;
        uint256 gpuCount;
        uint256 reserveAmount;
    }

    struct StakeHolderInfo {
        address holder;
        uint256 totalCalcPoint;
        uint256 totalGPUCount;
        uint256 totalReservedAmount;
        string[] machineIds;
        mapping(string => MachineInfo) machineId2Info;
    }

    struct SimpleStakeHolder {
        address holder;
        uint256 totalCalcPoint;
    }

    SimpleStakeHolder[3] public topStakeHolders;
    mapping(address => StakeHolderInfo) public stakeHolders;

    modifier onlyNftStakingAddress() {
        require(msg.sender == nftStakingAddress, "Only NFTStakingAddress can call this function");
        _;
    }

    function initialize(address _initialOwner, address _precompileContract, uint8 _phase_level) public initializer {
        __Ownable_init(_initialOwner);
        __UUPSUpgradeable_init();

        precompileContract = IPrecompileContract(_precompileContract);
        phaseLevel = _phase_level;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function setValidCaller(address caller) external onlyOwner {
        nftStakingAddress = caller;
    }

    function setPrecompileContract(address _precompileContract) external onlyOwner {
        precompileContract = IPrecompileContract(_precompileContract);
    }

    function findStringIndex(string[] memory arr, string memory v) internal pure returns (uint256) {
        for (uint256 i = 0; i < arr.length; i++) {
            if (keccak256(abi.encodePacked(arr[i])) == keccak256(abi.encodePacked(v))) {
                return i;
            }
        }
        revert("Element not found");
    }

    function getRentedGPUCountOfMachineInDlcNftStaking(string memory machineId) public view returns (uint256) {
        return precompileContract.getRentedGPUCountOfMachineInDlcNftStaking(phaseLevel, machineId);
    }

    function getDlcNftStakingBurnedRentFeeByMachine(string memory machineId) public view returns (uint256) {
        return precompileContract.getDlcNftStakingBurnedRentFeeByMachine(phaseLevel, machineId);
    }

    function getMachineCalcPoint(string memory machineId) public view returns (uint256) {
        return precompileContract.getMachineCalcPoint(machineId);
    }

    function getMachineGPUCount(string memory machineId) public view returns (uint256) {
        return precompileContract.getMachineGPUCount(machineId);
    }

    function removeStringValueOfArray(string memory addr, string[] storage arr) internal {
        uint256 index = findStringIndex(arr, addr);
        arr[index] = arr[arr.length - 1];
        arr.pop();
    }

    function addOrUpdateStakeHolder(
        address _holder,
        string memory _machineId,
        uint256 _calcPoint,
        uint256 _reservedAmount
    ) external onlyNftStakingAddress {
        StakeHolderInfo storage stakeHolderInfo = stakeHolders[_holder];

        if (stakeHolderInfo.holder == address(0)) {
            stakeHolderInfo.holder = _holder;
        }

        MachineInfo memory previousMachineInfo = stakeHolderInfo.machineId2Info[_machineId];
        stakeHolderInfo.machineId2Info[_machineId].calcPoint = _calcPoint;
        if (stakeHolderInfo.machineId2Info[_machineId].gpuCount == 0) {
            uint256 gpuCount = getMachineGPUCount(_machineId);

            stakeHolderInfo.machineId2Info[_machineId].gpuCount = gpuCount;

            stakeHolderInfo.totalGPUCount = stakeHolderInfo.totalGPUCount + gpuCount;
        }
        if (previousMachineInfo.reserveAmount == 0 && previousMachineInfo.calcPoint == 0) {
            stakeHolderInfo.totalReservedAmount += _reservedAmount;
            stakeHolderInfo.machineId2Info[_machineId].reserveAmount = _reservedAmount;
            stakeHolderInfo.machineIds.push(_machineId);
        }

        stakeHolderInfo.totalCalcPoint = stakeHolderInfo.totalCalcPoint + _calcPoint - previousMachineInfo.calcPoint;

        updateTopStakeHolders(_holder, stakeHolderInfo.totalCalcPoint);
    }

    function removeMachine(address _holder, string memory _machineId) external onlyNftStakingAddress {
        StakeHolderInfo storage stakeHolderInfo = stakeHolders[_holder];

        MachineInfo memory stakeInfoToRemove = stakeHolderInfo.machineId2Info[_machineId];
        require(stakeInfoToRemove.calcPoint > 0, "Machine not found");

        stakeHolderInfo.totalCalcPoint -= stakeInfoToRemove.calcPoint;
        stakeHolderInfo.totalGPUCount -= stakeInfoToRemove.gpuCount;
        stakeHolderInfo.totalReservedAmount -= stakeInfoToRemove.reserveAmount;
        removeStringValueOfArray(_machineId, stakeHolderInfo.machineIds);
        delete stakeHolderInfo.machineId2Info[_machineId];

        updateTopStakeHolders(_holder, stakeHolderInfo.totalCalcPoint);
    }

    function updateTopStakeHolders(address _holder, uint256 _totalCalcPoint) internal {
        uint256 minIndex = 0;
        bool shouldInsert = false;
        bool isExistingHolder = false;

        for (uint256 i = 0; i < topStakeHolders.length; i++) {
            if (topStakeHolders[i].holder == _holder) {
                if (_totalCalcPoint > topStakeHolders[i].totalCalcPoint) {
                    topStakeHolders[i].totalCalcPoint = _totalCalcPoint;
                    shouldInsert = true;
                }
                isExistingHolder = true;
                break;
            }
        }

        if (!isExistingHolder) {
            for (uint256 i = 1; i < topStakeHolders.length; i++) {
                if (topStakeHolders[i].totalCalcPoint < topStakeHolders[minIndex].totalCalcPoint) {
                    minIndex = i;
                }
            }

            if (
                topStakeHolders[minIndex].totalCalcPoint == 0
                    || _totalCalcPoint > topStakeHolders[minIndex].totalCalcPoint
            ) {
                topStakeHolders[minIndex] = SimpleStakeHolder(_holder, _totalCalcPoint);
                shouldInsert = true;
            }
        }

        if (shouldInsert) {
            sortTopStakeHolders();
        }
    }

    function sortTopStakeHolders() internal {
        for (uint256 i = 0; i < topStakeHolders.length - 1; i++) {
            for (uint256 j = i + 1; j < topStakeHolders.length; j++) {
                if (topStakeHolders[i].totalCalcPoint < topStakeHolders[j].totalCalcPoint) {
                    SimpleStakeHolder memory temp = topStakeHolders[i];
                    topStakeHolders[i] = topStakeHolders[j];
                    topStakeHolders[j] = temp;
                }
            }
        }
    }

    function getHolderMachineIds(address _holder) external view returns (string[] memory) {
        return stakeHolders[_holder].machineIds;
    }

    function getTotalGPUCountOfStakeHolder(address _holder) public view returns (uint256){
        uint256 totalGpuCount = 0;
        for (uint256 i = 0; i < stakeHolders[_holder].machineIds.length; i++) {
            string memory machineId = stakeHolders[_holder].machineIds[i];
            uint256 gpuCount = precompileContract.getMachineGPUCount(machineId);
            totalGpuCount += gpuCount;
        }
        return totalGpuCount;
    }


    function getRentedGPUCountOfStakeHolder(address _holder) external view returns (uint256) {
        uint256 totalRentedGpuCount = 0;
        for (uint256 i = 0; i < stakeHolders[_holder].machineIds.length; i++) {
            string memory machineId = stakeHolders[_holder].machineIds[i];
            uint256 rentedGpuCount = getRentedGPUCountOfMachineInDlcNftStaking(machineId);
            totalRentedGpuCount += rentedGpuCount;
        }
        return totalRentedGpuCount;
    }

    function getBurnedRentFeeOfStakeHolder(address _holder) external view returns (uint256) {
        uint256 totalRentedRentFee = 0;
        for (uint256 i = 0; i < stakeHolders[_holder].machineIds.length; i++) {
            string memory machineId = stakeHolders[_holder].machineIds[i];
            uint256 rentFee = getDlcNftStakingBurnedRentFeeByMachine(machineId);
            totalRentedRentFee += rentFee;
        }
        return totalRentedRentFee;
    }

    function getCalcPointOfStakeHolders(address _holder) external view returns (uint256) {
        uint256 totalCalcPoint = 0;
        for (uint256 i = 0; i < stakeHolders[_holder].machineIds.length; i++) {
            string memory machineId = stakeHolders[_holder].machineIds[i];
            uint256 calcPoint = getMachineCalcPoint(machineId);
            totalCalcPoint += calcPoint;
        }
        return totalCalcPoint;
    }

    function getTopStakeHolders()
        external
        view
        returns (address[3] memory top3HoldersAddress, uint256[3] memory top3HoldersCalcPoint)
    {
        for (uint256 i = 0; i < topStakeHolders.length; i++) {
            address holder = topStakeHolders[i].holder;
            uint256 totalCalcPoint = topStakeHolders[i].totalCalcPoint;
            top3HoldersAddress[i] = holder;
            top3HoldersCalcPoint[i] = totalCalcPoint;
        }

        return (top3HoldersAddress, top3HoldersCalcPoint);
    }

    function version() external pure returns (uint256) {
        return 2;
    }
}
