// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../interface/IStakingContract.sol";
import "../interface/IRewardToken.sol";
import "../interface/IRentContract.sol";
import "../interface/IPrecompileContract.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/// @custom:oz-upgrades-from OldRent
contract OldRent is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    uint8 public constant SECONDS_PER_BLOCK = 6;
    uint256 public constant REPORT_RESERVE_AMOUNT = 10000 * 1e18;
    uint256 public constant SLASH_AMOUNT = 10000 * 1e18;

    IRewardToken public feeToken;
    IPrecompileContract public precompileContract;
    IStakingContract public stakingContract;

    uint256 public lastRentId;
    uint256 public totalBurnedAmount;
    uint8 public voteThreshold;
    bool public registered;
    RentGPUInfo public rentGPUInfo;

    enum SlashType {
        Offline,
        RenterReport
    }

    enum NotifyType {
        ContractRegister,
        MachineRegister,
        MachineUnregister,
        MachineOnline,
        MachineOffline
    }

    enum Vote {
        None,
        Yes,
        No,
        Finished
    }

    struct RentInfo {
        address stakeHolder;
        string machineId;
        uint256 rentStatTime;
        uint256 rentEndTime;
        address renter;
    }

    struct BurnedDetail {
        uint256 rentId;
        uint256 burnTime;
        uint256 burnDLCAmount;
        address renter;
    }

    struct BurnedInfo {
        BurnedDetail[] details;
        uint256 totalBurnedAmount;
    }

    struct SlashInfo {
        address stakeHolder;
        string machineId;
        uint256 slashAmount;
        uint256 rentStartAtTimestamp;
        uint256 rentEndAtTimestamp;
        uint256 rentedDurationSeconds;
        address renter;
        SlashType slashType;
        uint256 createdAt;
        bool paid;
    }

    struct RentGPUInfo {
        uint256 rentedGPUCount;
        uint256 rentingGPUCount;
    }

    address[] public adminsToApprove;
    string[] public pendingSlashMachineIds;

    mapping(uint256 => RentInfo) public rentId2RentInfo;
    mapping(string => uint256) public machineId2RentId;
    mapping(address => uint256[]) public renter2RentIds;
    mapping(string => BurnedInfo) public machineId2BurnedInfo;
    mapping(string => SlashInfo) public machineId2SlashInfo;
    mapping(string => SlashInfo[]) public machineId2SlashInfos;
    mapping(string => mapping(address => Vote)) public pendingSlashMachineId2ApprovedAdmins;
    mapping(string => uint8) public pendingSlashMachineId2ApprovedCount;
    mapping(string => uint8) public pendingSlashMachineId2RefuseCount;
    mapping(address => uint256) public stakeHolder2RentFee;

    mapping(address => RentGPUInfo) public stakeHolder2RentGPUInfo;
    mapping(string => uint256) public machineId2LastRentEndBlock;
    address public canUpgradeAddress;
    uint256 public constant ONE_CALC_POINT_USD_VALUE_PER_MONTH = 5_080;
    uint256 public constant FACTOR = 10_000;
    uint256 public constant USD_DECIMALS = 1_000_000;

    event RentMachine(
        uint256 rentId, string machineId, uint256 rentEndTime, uint8 gpuCount, address renter, uint256 rentFee
    );
    event RenewRent(uint256 rentId, uint256 additionalRentSeconds, uint256 additionalRentFee, address renter);
    event EndRentMachine(uint256 rentId, string machineId, uint256 rentEndTime, address renter);
    event ReportMachineFault(uint256 rentId, string machineId, address reporter);
    event BurnedFee(
        string machineId, uint256 rentId, uint256 burnTime, uint256 burnDLCAmount, address renter, uint8 rentGpuCount
    );
    event ApprovedReport(string machineId, address admin);
    event RefusedReport(string machineId, address admin);
    event ExecuteReport(string machineId, Vote vote);
    event MachineRegister(string machineId, uint256 calcPoint);
    event MachineUnregister(string machineId, uint256 calcPoint);
    event PaidSlash(string machineId);

    modifier onlyApproveAdmins() {
        bool found = false;
        for (uint8 i = 0; i < adminsToApprove.length; i++) {
            if (msg.sender == adminsToApprove[i]) {
                found = true;
                break;
            }
        }
        require(found, "not approve admin");
        _;
    }

    modifier onlyStakingContract() {
        require(msg.sender == address(stakingContract), "only staking contract");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _initialOwner, address _precompileContract, address _stakingContract, address _feeToken)
        public
        initializer
    {
        __Ownable_init(_initialOwner);
        __UUPSUpgradeable_init();
        feeToken = IRewardToken(_feeToken);
        precompileContract = IPrecompileContract(_precompileContract);
        stakingContract = IStakingContract(_stakingContract);
        voteThreshold = 3;
        canUpgradeAddress = msg.sender;
    }

    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
        require(newImplementation != address(0), "new implementation is the zero address");
        require(
            msg.sender == canUpgradeAddress || msg.sender == owner(), "only canUpgradeAddress can authorize upgrade"
        );
    }

    function setAdminsToApproveMachineFaultReporting(address[] calldata admins) external onlyOwner {
        require(admins.length == 5, "admins length should be 5");
        adminsToApprove = admins;
    }

    function setFeeToken(address _feeToken) external onlyOwner {
        require(_feeToken != address(0x0), "fee token address should not be 0x0");
        feeToken = IRewardToken(_feeToken);
    }

    function setCanUpgradeAddress(address addr) external onlyOwner {
        canUpgradeAddress = addr;
    }

    function setStakingContract(address addr) external onlyOwner {
        stakingContract = IStakingContract(addr);
    }

    function setPrecompileContract(address _precompileContract) external onlyOwner {
        require(_precompileContract != address(0x0), "precompile contract address should not be 0x0");
        precompileContract = IPrecompileContract(_precompileContract);
    }

    function findUintIndex(uint256[] memory arr, uint256 v) internal pure returns (uint256) {
        for (uint256 i = 0; i < arr.length; i++) {
            if (arr[i] == v) {
                return i;
            }
        }
        revert("Element not found");
    }

    function removeValueOfUintArray(uint256 v, uint256[] storage arr) internal {
        uint256 index = findUintIndex(arr, v);
        arr[index] = arr[arr.length - 1];
        arr.pop();
    }

    function findStringIndex(string[] memory arr, string memory v) internal pure returns (uint256) {
        for (uint256 i = 0; i < arr.length; i++) {
            if (keccak256(abi.encodePacked(arr[i])) == keccak256(abi.encodePacked(v))) {
                return i;
            }
        }
        revert("Element not found");
    }

    function removeValueOfStringArray(string memory addr, string[] storage arr) internal {
        uint256 index = findStringIndex(arr, addr);
        arr[index] = arr[arr.length - 1];
        arr.pop();
    }

    function getNextRentId() internal returns (uint256) {
        require(lastRentId < type(uint256).max, "ID overflow");
        lastRentId += 1;
        return lastRentId;
    }

    function canRent(string calldata machineId) public view returns (bool) {
        if (isRented(machineId)) {
            return false;
        }

        if (!stakingContract.isStaking(machineId)) {
            return false;
        }
        (, uint256 calcPoint,, uint256 endAtTimestamp, uint256 nextRenterCanRentAt,) =
            stakingContract.getMachineInfo(machineId);
        if (isRented(machineId) || calcPoint == 0) {
            return false;
        }

        if (nextRenterCanRentAt > block.timestamp) {
            // not reach the start rent block number yet
            return false;
        }

        return endAtTimestamp > block.timestamp;
    }

    function getMachinePrice(string memory machineId, uint256 rentSeconds) public view returns (uint256) {
        uint256 calcPointInFact = precompileContract.getMachineCalcPoint(machineId);
        require(calcPointInFact > 0, "machine calcPoint is 0 now");

        // calcPont factor : 10000 ; ONE_CALC_POINT_USD_VALUE_PER_MONTH factor: 10000
        uint256 totalFactor = FACTOR * FACTOR;
        // 0.005U
        uint256 dlcUSDPrice = 5000;
        uint256 rentFeeUSD = USD_DECIMALS * rentSeconds * calcPointInFact * ONE_CALC_POINT_USD_VALUE_PER_MONTH / 30 / 24
            / 60 / 60 / totalFactor;
        return 1e18 * rentFeeUSD / dlcUSDPrice;
    }

    function rentMachine(string calldata machineId, uint256 rentSeconds) external {
        require(rentSeconds > 0, "rent duration should be greater than 0");
        require(canRent(machineId), "machine can not rent");

        require(rentSeconds >= 10 minutes, "rent duration should be greater than 10 minutes");
        (address machineHolder,,, uint256 endAtTimestamp,,) = stakingContract.getMachineInfo(machineId);
        (,, uint256 rewardEndAt) = stakingContract.getGlobalState();
        require(rewardEndAt > 60 days, "reward not start");
        uint256 maxRentDuration = Math.min(Math.min(endAtTimestamp, rewardEndAt), 60 days);
        require(rentSeconds <= maxRentDuration, "rent duration should be less than max rent duration");

        uint256 lastRentEndBlock = machineId2LastRentEndBlock[machineId];
        if (lastRentEndBlock != 0) {
            require(block.number > lastRentEndBlock + 100, "machine can not rent too frequently");
        }

        uint256 rentFeeInFact = getMachinePrice(machineId, rentSeconds);
        require(feeToken.balanceOf(msg.sender) >= rentFeeInFact, "balance not enough");

        uint256 _now = block.timestamp;

        // save rent info
        lastRentId = getNextRentId();
        rentId2RentInfo[lastRentId] = RentInfo({
            stakeHolder: machineHolder,
            machineId: machineId,
            rentStatTime: _now,
            rentEndTime: _now + rentSeconds,
            renter: msg.sender
        });
        machineId2RentId[machineId] = lastRentId;
        renter2RentIds[msg.sender].push(lastRentId);

        // burn rent fee
        feeToken.burnFrom(msg.sender, rentFeeInFact);
        emit BurnedFee(machineId, lastRentId, block.timestamp, rentFeeInFact, msg.sender, 1);

        // add machine burn info
        BurnedDetail memory burnedDetail = BurnedDetail({
            rentId: lastRentId,
            burnTime: block.timestamp,
            burnDLCAmount: rentFeeInFact,
            renter: msg.sender
        });

        stakeHolder2RentGPUInfo[machineHolder].rentedGPUCount += 1;
        stakeHolder2RentGPUInfo[machineHolder].rentingGPUCount += 1;
        rentGPUInfo.rentedGPUCount += 1;
        rentGPUInfo.rentingGPUCount += 1;

        stakeHolder2RentFee[machineHolder] += rentFeeInFact;
        BurnedInfo storage burnedInfo = machineId2BurnedInfo[machineId];
        burnedInfo.details.push(burnedDetail);
        burnedInfo.totalBurnedAmount += rentFeeInFact;

        // update total burned amount
        totalBurnedAmount += rentFeeInFact;

        // notify staking contract renting machine action happened
        stakingContract.rentMachine(machineId, rentFeeInFact);

        stakingContract.setBurnedRentFee(machineHolder, machineId, rentFeeInFact);
        stakingContract.addRentedGPUCount(machineHolder, machineId);

        emit RentMachine(lastRentId, machineId, block.timestamp + rentSeconds, 1, msg.sender, rentFeeInFact);
    }

    function renewRent(string memory machineId, uint256 additionalRentSeconds) external {
        uint256 rentId = machineId2RentId[machineId];
        require(rentId2RentInfo[rentId].rentEndTime > block.timestamp, "rent end");
        require(rentId2RentInfo[rentId].renter == msg.sender, "Only the renter can renew the rent");
        require(isRented(machineId), "Machine is not currently rented");
        require(additionalRentSeconds >= 10 minutes, "Additional rent duration should be greater than 10 minutes");

        (address machineHolder,,, uint256 endAtTimestamp,,) = stakingContract.getMachineInfo(machineId);
        (,, uint256 rewardEndAt) = stakingContract.getGlobalState();
        uint256 maxRentDuration = Math.min(Math.min(endAtTimestamp, rewardEndAt), 60 days);
        require(additionalRentSeconds <= maxRentDuration, "rent duration should be less than max rent duration");

        uint256 additionalRentFeeInFact = getMachinePrice(rentId2RentInfo[rentId].machineId, additionalRentSeconds);
        require(feeToken.balanceOf(msg.sender) >= additionalRentFeeInFact, "Additional rent fee not enough");

        // Update rent end time
        rentId2RentInfo[rentId].rentEndTime += additionalRentSeconds;

        // Burn additional rent fee
        feeToken.burnFrom(msg.sender, additionalRentFeeInFact);

        emit BurnedFee(machineId, rentId, block.timestamp, additionalRentFeeInFact, msg.sender, 1);

        // add machine burn info
        BurnedDetail memory burnedDetail = BurnedDetail({
            rentId: rentId,
            burnTime: block.timestamp,
            burnDLCAmount: additionalRentFeeInFact,
            renter: msg.sender
        });

        stakeHolder2RentFee[machineHolder] += additionalRentFeeInFact;
        BurnedInfo storage burnedInfo = machineId2BurnedInfo[machineId];
        burnedInfo.details.push(burnedDetail);
        burnedInfo.totalBurnedAmount += additionalRentFeeInFact;

        // update total burned amount
        totalBurnedAmount += additionalRentFeeInFact;

        stakingContract.setBurnedRentFee(machineHolder, machineId, additionalRentFeeInFact);
        emit RenewRent(rentId, additionalRentSeconds, additionalRentFeeInFact, msg.sender);
    }

    function endRentMachine(string calldata machineId) external {
        uint256 rentId = machineId2RentId[machineId];
        RentInfo memory rentInfo = rentId2RentInfo[rentId];
        require(rentInfo.rentEndTime <= block.timestamp, "rent not end");

        (address machineHolder,) = getMachineHolderAndCalcPoint(machineId);

        removeValueOfUintArray(rentId, renter2RentIds[rentInfo.renter]);
        delete rentId2RentInfo[rentId];
        delete machineId2RentId[machineId];

        stakeHolder2RentGPUInfo[machineHolder].rentingGPUCount -= 1;
        rentGPUInfo.rentingGPUCount -= 1;

        stakingContract.endRentMachine(machineId);
        machineId2LastRentEndBlock[machineId] = block.number;
        emit EndRentMachine(rentId, machineId, rentInfo.rentEndTime, rentInfo.renter);
    }

    function getMachineHolderAndCalcPoint(string memory machineId) internal view returns (address, uint256) {
        (address holder, uint256 calcPoint,,,,) = stakingContract.getMachineInfo(machineId);
        return (holder, calcPoint);
    }

    function reportMachineFault(string calldata machineId, uint256 reserveAmount) external {
        require(reserveAmount == REPORT_RESERVE_AMOUNT, "reserve amount should be 10000");

        uint256 rentId = machineId2RentId[machineId];
        RentInfo memory rentInfo = rentId2RentInfo[rentId];
        require(rentInfo.renter == msg.sender, "not rent owner");
        require(rentInfo.rentEndTime >= block.timestamp, "rent end");

        feeToken.transferFrom(msg.sender, address(this), REPORT_RESERVE_AMOUNT);

        machineId2SlashInfo[rentInfo.machineId] = newSlashInfo(
            rentInfo.stakeHolder,
            rentInfo.machineId,
            SLASH_AMOUNT,
            rentInfo.rentStatTime,
            rentInfo.rentEndTime,
            block.timestamp - rentInfo.rentStatTime,
            SlashType.RenterReport,
            rentInfo.renter
        );
        pendingSlashMachineIds.push(rentInfo.machineId);
        emit ReportMachineFault(rentId, rentInfo.machineId, msg.sender);
    }

    function newSlashInfo(
        address slasher,
        string memory machineId,
        uint256 slashAmount,
        uint256 rentStartAt,
        uint256 rentEndAt,
        uint256 rentDuration,
        SlashType slashType,
        address renter
    ) internal view returns (SlashInfo memory) {
        SlashInfo memory slashInfo = SlashInfo({
            stakeHolder: slasher,
            machineId: machineId,
            slashAmount: slashAmount,
            rentStartAtTimestamp: rentStartAt,
            rentEndAtTimestamp: rentEndAt,
            rentedDurationSeconds: rentDuration,
            renter: renter,
            slashType: slashType,
            createdAt: block.timestamp,
            paid: false
        });
        return slashInfo;
    }

    function addSlashInfoAndReport(SlashInfo memory slashInfo) internal {
        machineId2SlashInfos[slashInfo.machineId].push(slashInfo);
        stakingContract.reportMachineFault(slashInfo.machineId, slashInfo.renter);
    }

    function approveMachineFaultReporting(string calldata machineId) external onlyApproveAdmins {
        require(machineId2SlashInfo[machineId].renter != address(0x0), "not found reported machine");

        require(pendingSlashMachineId2ApprovedAdmins[machineId][msg.sender] != Vote.Finished, "vote already finished");
        pendingSlashMachineId2ApprovedAdmins[machineId][msg.sender] = Vote.Yes;
        emit ApprovedReport(machineId, msg.sender);
        pendingSlashMachineId2ApprovedCount[machineId] += 1;
        if (pendingSlashMachineId2ApprovedCount[machineId] >= voteThreshold) {
            SlashInfo memory slashInfo = machineId2SlashInfo[machineId];
            addSlashInfoAndReport(slashInfo);

            removeValueOfStringArray(machineId, pendingSlashMachineIds);
            delete machineId2SlashInfo[machineId];
            delete pendingSlashMachineId2ApprovedCount[machineId];

            for (uint8 i = 0; i < adminsToApprove.length; i++) {
                pendingSlashMachineId2ApprovedAdmins[machineId][adminsToApprove[i]] = Vote.Finished;
            }

            feeToken.transfer(slashInfo.renter, REPORT_RESERVE_AMOUNT);
            emit ExecuteReport(machineId, Vote.Yes);
        }
    }

    function rejectMachineFaultReporting(string calldata machineId) external onlyApproveAdmins {
        require(machineId2SlashInfo[machineId].renter != address(0), "not found reported machine");

        require(pendingSlashMachineId2ApprovedAdmins[machineId][msg.sender] != Vote.Finished, "vote already finished");
        pendingSlashMachineId2ApprovedAdmins[machineId][msg.sender] = Vote.No;
        pendingSlashMachineId2RefuseCount[machineId] += 1;
        emit RefusedReport(machineId, msg.sender);
        if (pendingSlashMachineId2RefuseCount[machineId] >= voteThreshold) {
            removeValueOfStringArray(machineId, pendingSlashMachineIds);
            delete machineId2SlashInfo[machineId];
            delete pendingSlashMachineId2ApprovedCount[machineId];

            for (uint8 i = 0; i < adminsToApprove.length; i++) {
                pendingSlashMachineId2ApprovedAdmins[machineId][adminsToApprove[i]] = Vote.Finished;
            }

            uint256 amountPerAdmin = REPORT_RESERVE_AMOUNT / adminsToApprove.length;
            for (uint256 i = 0; i < adminsToApprove.length; i++) {
                if (adminsToApprove[i] == address(0)) {
                    continue;
                }
                feeToken.transfer(adminsToApprove[i], amountPerAdmin);
            }

            delete machineId2SlashInfo[machineId];
            delete pendingSlashMachineId2RefuseCount[machineId];

            emit ExecuteReport(machineId, Vote.No);
        }
    }

    function version() external pure returns (uint256) {
        return 1;
    }

    function getBurnedRentFeeByStakeHolder(address stakeHolder) public view returns (uint256) {
        return stakeHolder2RentFee[stakeHolder];
    }

    function getTotalBurnedRentFee() public view returns (uint256) {
        return totalBurnedAmount;
    }

    function getRentedGPUCountOfStakeHolder(address stakeHolder) public view returns (uint256) {
        return stakeHolder2RentGPUInfo[stakeHolder].rentedGPUCount;
    }

    function getTotalRentedGPUCount() public view returns (uint256) {
        return rentGPUInfo.rentedGPUCount;
    }

    function isRented(string memory machineId) public view returns (bool) {
        uint256 rentId = machineId2RentId[machineId];
        RentInfo memory rentInfo = rentId2RentInfo[rentId];
        if (rentInfo.renter != address(0)) {
            return true;
        }
        uint256 lastRentEndBlock = machineId2LastRentEndBlock[machineId];
        if (lastRentEndBlock > 0) {
            return block.number <= lastRentEndBlock + 100;
        }
        return false;
    }

    function getRenter(string calldata machineId) public view returns (address) {
        uint256 rentId = machineId2RentId[machineId];
        address renter = rentId2RentInfo[rentId].renter;
        return renter;
    }

    function getSlashInfosByMachineId(string memory machineId, uint256 pageNumber, uint256 pageSize)
        external
        view
        returns (SlashInfo[] memory paginatedSlashInfos, uint256 totalCount)
    {
        require(pageNumber > 0, "Page number must be greater than zero");
        require(pageSize > 0, "Page size must be greater than zero");

        // Get the total number of SlashInfo for the given machineOwner
        totalCount = machineId2SlashInfos[machineId].length;
        if (totalCount == 0) {
            return (new SlashInfo[](0), totalCount);
        }

        // Calculate the start index for the requested page
        uint256 startIndex = (pageNumber - 1) * pageSize;

        // Ensure startIndex is within bounds
        if (startIndex >= totalCount) {
            return (new SlashInfo[](0), totalCount);
        }

        // Calculate the end index for pagination
        uint256 endIndex = startIndex + pageSize > totalCount ? totalCount : startIndex + pageSize;
        uint256 resultSize = endIndex - startIndex;

        // Create a new array for paginated results
        paginatedSlashInfos = new SlashInfo[](resultSize);

        // Populate the paginated array
        for (uint256 i = 0; i < resultSize; i++) {
            paginatedSlashInfos[i] = machineId2SlashInfos[machineId][startIndex + i];
        }
    }

    function paidSlash(string memory machineId) external onlyStakingContract {
        console.log("paidSlash machineId: ", machineId);
        SlashInfo[] storage slashInfos = machineId2SlashInfos[machineId];
        for (uint256 i = 0; i < slashInfos.length; i++) {
            if (slashInfos[i].paid) {
                return;
            }
            if (keccak256(abi.encodePacked(slashInfos[i].machineId)) == keccak256(abi.encodePacked(machineId))) {
                slashInfos[i].paid = true;
                emit PaidSlash(machineId);
            }
        }
    }

    function isInSlashing(string memory machineId) public view returns (bool) {
        return machineId2SlashInfo[machineId].paid == false;
    }
}
