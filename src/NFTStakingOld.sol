// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "./interface/IStateContract.sol";
import "./interface/IRewardToken.sol";
import "./interface/IRentContract.sol";
import "./interface/ITool.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interface/IPrecompileContract.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./library/RewardCalculatorLib.sol";

/// @custom:oz-upgrades-from OldNFTStaking
contract OldNFTStaking is
    Initializable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    IERC1155Receiver
{
    string public constant PROJECT_NAME = "deeplink";
    uint256 public constant INIT_REWARD_AMOUNT = 1_000_000_000 * 1e18;
    uint8 public constant SECONDS_PER_BLOCK = 6;
    uint256 public constant BASE_RESERVE_AMOUNT = 10000 * 1e18;
    uint256 public constant REWARD_DURATION = 60 days;
    uint8 public constant MAX_NFTS_PER_MACHINE = 20;
    //        uint256 public constant REWARD_DURATION = 0.5 days; //todo: change to 60 days. 0.5 day only for test
    uint256 public constant LOCK_PERIOD = 180 days;

    IStateContract public stateContract;
    IRentContract public rentContract;
    ITool public toolContract;
    IERC1155 public nftToken;
    IRewardToken public rewardToken;
    IPrecompileContract public precompileContract;

    address private canUpgradeAddress;
    uint256 public totalDistributedRewardAmount;
    uint256 public rewardStartGPUThreshold;
    uint256 public rewardStartAtTimestamp;
    uint256 public rewardStartAtBlockNumber;

    uint256 public initRewardAmount;
    uint256 public totalReservedAmount;
    uint256 public totalCalcPoint;
    uint256 public totalStakedGpuCount;
    uint256 public totalStakingGpuCount;

    uint256 public totalAdjustUnit;
    uint256 public dailyRewardAmount;

    struct LockedRewardDetail {
        uint256 totalAmount;
        uint256 lockTime;
        uint256 unlockTime;
        uint256 claimedAmount;
    }

    struct ApprovedReportInfo {
        address renter;
    }

    struct StakeInfo {
        address holder;
        uint256 startAtTimestamp;
        uint256 lastClaimAtTimestamp;
        uint256 endAtTimestamp;
        uint256 calcPoint;
        uint256 reservedAmount;
        uint256[] nftTokenIds;
        uint256[] tokenIdBalances;
        uint256 nftCount;
        uint256 claimedAmount;
        bool isRentedByUser;
        uint256 gpuCount;
        uint256 nextRenterCanRentAt;
        uint256 rentId;
    }

    struct MachineInfoForDBCScan {
        bool isStaking;
        string gpuType;
        uint8 gpuCount;
        uint256 mem;
        string projectName;
        uint256 totalRewardAmount;
        uint256 claimedRewardAmount;
        uint256 lockedRewardAmount;
    }

    mapping(address => bool) public dlcClientWalletAddress;

    mapping(address => string[]) public holder2MachineIds;

    mapping(string => LockedRewardDetail) public machineId2LockedRewardDetail;

    mapping(string => ApprovedReportInfo[]) private pendingSlashedMachineId2Renter;

    mapping(string => StakeInfo) public machineId2StakeInfos;
    mapping(string => RewardCalculatorLib.UserRewards) public machineId2StakeUnitRewards;
    RewardCalculatorLib.RewardsPerShare public rewardsPerCalcPoint;

    event staked(address indexed stakeholder, string machineId);
    event reserveDLC(string machineId, uint256 amount);
    event unStaked(address indexed stakeholder, string machineId);
    event claimed(
        address indexed stakeholder,
        string machineId,
        uint256 rewardAmount,
        uint256 moveToReservedAmount,
        bool paidSlash
    );
    //    event AddNFTs(string machineId, uint256[] nftTokenIds);
    event PaySlash(string machineId, address renter, uint256 slashAmount);
    event RentMachine(string machineId);
    event EndRentMachine(string machineId);
    event ReportMachineFault(string machineId, address renter);
    event DepositReward(uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function onERC1155BatchReceived(
        address, /* unusedParameter */
        address, /* unusedParameter */
        uint256[] calldata, /* unusedParameter */
        uint256[] calldata, /* unusedParameter */
        bytes calldata /* unusedParameter */
    ) external pure override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function onERC1155Received(
        address, /* unusedParameter */
        address, /* unusedParameter */
        uint256, /* unusedParameter */
        uint256, /* unusedParameter */
        bytes calldata /* unusedParameter */
    ) external pure override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId;
    }

    modifier onlyRentContractOrThis() {
        require(
            msg.sender == address(rentContract) || msg.sender == address(this),
            "only rent contract or this can call this function"
        );
        _;
    }

    modifier onlyRentContract() {
        require(msg.sender == address(rentContract), "only rent contract can call this function");
        _;
    }

    function initialize(
        address _initialOwner,
        address _nftToken,
        address _rewardToken,
        address _stateContract,
        address _rentContract,
        address _toolContract,
        address _precompileContract,
        uint8 phaseLevel
    ) public initializer {
        __ReentrancyGuard_init();
        __Ownable_init(_initialOwner);
        __UUPSUpgradeable_init();

        rewardToken = IRewardToken(_rewardToken);
        nftToken = IERC1155(_nftToken);
        stateContract = IStateContract(_stateContract);
        rentContract = IRentContract(_rentContract);
        precompileContract = IPrecompileContract(_precompileContract);

        if (phaseLevel == 1) {
            rewardStartGPUThreshold = 500;
            initRewardAmount = 360000000 ether;
        }
        if (phaseLevel == 2) {
            rewardStartGPUThreshold = 1000;
            initRewardAmount = 480000000 ether;
        }
        if (phaseLevel == 3) {
            rewardStartGPUThreshold = 2000;
            initRewardAmount = 116000000 ether;
        }

        dailyRewardAmount = initRewardAmount / 60;

        rewardStartAtTimestamp = 0;
        rewardStartAtBlockNumber = 0;
        canUpgradeAddress = msg.sender;

        setToolContract(ITool(_toolContract));
    }

    function setToolContract(ITool _toolContract) internal onlyOwner {
        toolContract = _toolContract;
    }

    function setThreshold(uint256 _threshold) public onlyOwner {
        rewardStartGPUThreshold = _threshold;
    }

    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
        require(newImplementation != address(0), "new implementation is the zero address");
        require(msg.sender == canUpgradeAddress, "only canUpgradeAddress can authorize upgrade");
    }

    function getUpgradeAddress() external view onlyOwner returns (address) {
        return canUpgradeAddress;
    }

    function setUpgradeAddress(address addr) external onlyOwner {
        canUpgradeAddress = addr;
    }

    function requestUpgradeAddress(address addr) external pure returns (bytes memory) {
        bytes memory data = abi.encodeWithSignature("setUpgradeAddress(address)", addr);
        return data;
    }

    function setStateContract(address _stateContract) external onlyOwner {
        stateContract = IStateContract(_stateContract);
    }

    function setRewardToken(address token) external onlyOwner {
        rewardToken = IRewardToken(token);
    }

    function setRentContract(address _rentContract) external onlyOwner {
        rentContract = IRentContract(_rentContract);
    }

    function setNftToken(address token) external onlyOwner {
        nftToken = IERC1155(token);
    }

    function setRewardStartAt(uint256 timestamp) external onlyOwner {
        require(timestamp >= block.timestamp, "time must be greater than current block number");
        rewardStartAtTimestamp = timestamp;
    }

    function setDLCClientWallets(address[] calldata addrs) external onlyOwner {
        for (uint256 i = 0; i < addrs.length; i++) {
            require(addrs[i] != address(0), "address is zero");
            require(dlcClientWalletAddress[addrs[i]] == false, "address already added");
            dlcClientWalletAddress[addrs[i]] = true;
        }
    }

    function addDLCToStake(string memory machineId, uint256 amount) external nonReentrant {
        require(isStaking(machineId), "machine not staked");
        if (amount == 0) {
            return;
        }
        StakeInfo storage stakeInfo = machineId2StakeInfos[machineId];

        ApprovedReportInfo[] memory approvedReportInfos = pendingSlashedMachineId2Renter[machineId];
        if (approvedReportInfos.length > 0) {
            require(
                amount >= BASE_RESERVE_AMOUNT * approvedReportInfos.length, "amount must be greater than slash amount"
            );
            for (uint8 i = 0; i < approvedReportInfos.length; i++) {
                // pay slash to renters
                payToRenterForSlashing(machineId, stakeInfo, approvedReportInfos[i].renter, false);
                amount -= BASE_RESERVE_AMOUNT;
            }
            delete pendingSlashedMachineId2Renter[machineId];
        }

        _joinStaking(machineId, stakeInfo.calcPoint, amount + stakeInfo.reservedAmount);
        stateContract.addReserveAmount(stakeInfo.holder, machineId, amount);
        emit reserveDLC(machineId, amount);
    }

    function stake(
        string calldata machineId,
        uint256[] calldata nftTokenIds,
        uint256[] calldata nftTokenIdBalances,
        uint256 rentId
    ) external nonReentrant {
        require(nftTokenIds.length == nftTokenIdBalances.length, "nft token ids and balances length not match");
        uint256 calcPoint = precompileContract.getMachineCalcPoint(machineId);
        require(precompileContract.getMachineGPUCount(machineId) == 1, "only one gpu per machine can stake");
        uint256 cpuRate = precompileContract.getMachineCPURate(machineId);
        require(cpuRate >= 3500, "cpu rate must be greater than or equal to 3500");
        require(
            precompileContract.isMachineOwner(machineId, msg.sender) || dlcClientWalletAddress[msg.sender],
            "sender must be machine owner or admin"
        );
        require(calcPoint > 0, "machine calc point not found");
        require(!rewardEnd(), "staking ended");

        address stakeholder = msg.sender;
        require(!isStaking(machineId), "machine already staked");
        require(nftTokenIds.length > 0, "nft token ids is empty");
        uint256 nftCount = getNFTCount(nftTokenIdBalances);
        require(nftCount <= MAX_NFTS_PER_MACHINE, "nft count must be less than or equal to 20");
        calcPoint = calcPoint * nftCount;
        uint256 rentEndAt = precompileContract.getOwnerRentEndAt(machineId, rentId);
        if (rewardStartAtTimestamp > 0) {
            require(
                (rentEndAt - rewardStartAtBlockNumber) * SECONDS_PER_BLOCK >= REWARD_DURATION,
                "rent time must be greater than 60 days since reward start"
            );
        } else {
            require(
                (rewardStartAtTimestamp - block.timestamp) >= REWARD_DURATION,
                "rent time must be greater than 60 days since reward start"
            );
        }

        uint256 currentTime = block.timestamp;
        uint8 gpuCount = 1;
        totalStakedGpuCount += gpuCount;
        totalStakedGpuCount += gpuCount;
        if (totalStakedGpuCount >= rewardStartGPUThreshold) {
            rewardStartAtTimestamp = currentTime;
            rewardsPerCalcPoint.lastUpdated = currentTime;
            rewardStartAtBlockNumber = block.number;
        }

        nftToken.safeBatchTransferFrom(stakeholder, address(this), nftTokenIds, nftTokenIdBalances, "transfer");
        machineId2StakeInfos[machineId] = StakeInfo({
            startAtTimestamp: currentTime,
            lastClaimAtTimestamp: currentTime,
            endAtTimestamp: 0,
            calcPoint: 0,
            reservedAmount: 0,
            nftTokenIds: nftTokenIds,
            tokenIdBalances: nftTokenIdBalances,
            nftCount: nftCount,
            holder: stakeholder,
            claimedAmount: 0,
            isRentedByUser: false,
            gpuCount: gpuCount,
            nextRenterCanRentAt: currentTime,
            rentId: rentId
        });

        _joinStaking(machineId, calcPoint, 0);
        if (machineId2LockedRewardDetail[machineId].lockTime == 0) {
            machineId2LockedRewardDetail[machineId] = LockedRewardDetail({
                totalAmount: 0,
                lockTime: currentTime,
                unlockTime: currentTime + LOCK_PERIOD,
                claimedAmount: 0
            });
        }
        stateContract.addOrUpdateStakeHolder(stakeholder, machineId, calcPoint, gpuCount, true);
        holder2MachineIds[stakeholder].push(machineId);

        emit staked(stakeholder, machineId);
    }

    function joinStaking(string memory machineId, uint256 calcPoint, uint256 reserveAmount) external {
        require(msg.sender == address(rentContract), "sender must be rent contract");
        _joinStaking(machineId, calcPoint, reserveAmount);
    }

    function getPendingSlashCount(string memory machineId) public view returns (uint256) {
        return pendingSlashedMachineId2Renter[machineId].length;
    }

    function getRewardInfo(string memory machineId)
        public
        view
        returns (uint256 newRewardAmount, uint256 canClaimAmount, uint256 lockedAmount, uint256 claimedAmount)
    {
        StakeInfo storage stakeInfo = machineId2StakeInfos[machineId];

        uint256 totalRewardAmount = calculateRewards(machineId);
        (uint256 _canClaimAmount, uint256 _lockedAmount) = _getRewardDetail(totalRewardAmount);
        (uint256 dailyReleaseAmount, uint256 lockedAmountBefore) = calculateReleaseReward(machineId);

        return (
            totalRewardAmount,
            _canClaimAmount + dailyReleaseAmount,
            _lockedAmount + lockedAmountBefore,
            stakeInfo.claimedAmount
        );
    }

    function getNFTCount(uint256[] calldata nftTokenIdBalances) internal pure returns (uint256 nftCount) {
        for (uint256 i = 0; i < nftTokenIdBalances.length; i++) {
            nftCount += nftTokenIdBalances[i];
        }

        return nftCount;
    }

    function _claim(string memory machineId) internal {
        require(rewardStart(), "reward not start yet");
        StakeInfo storage stakeInfo = machineId2StakeInfos[machineId];
        address stakeholder = stakeInfo.holder;
        uint256 currentTimestamp = block.timestamp;

        bool _isStaking = isStaking(machineId);

        uint256 rewardAmount = calculateRewards(machineId);

        _updateRewardPerCalcPoint();
        machineId2StakeUnitRewards[machineId].accumulated = 0;

        (uint256 canClaimAmount, uint256 lockedAmount) = _getRewardDetail(rewardAmount);

        (uint256 _dailyReleaseAmount,) = calculateReleaseRewardAndUpdate(machineId);
        canClaimAmount += _dailyReleaseAmount;

        ApprovedReportInfo[] storage approvedReportInfos = pendingSlashedMachineId2Renter[machineId];
        bool slashed = approvedReportInfos.length > 0;
        uint256 moveToReserveAmount = 0;
        if (canClaimAmount > 0 && (_isStaking || slashed)) {
            if (stakeInfo.reservedAmount < BASE_RESERVE_AMOUNT) {
                (uint256 _moveToReserveAmount, uint256 leftAmountCanClaim) =
                    tryMoveReserve(machineId, canClaimAmount, stakeInfo);
                canClaimAmount = leftAmountCanClaim;
                moveToReserveAmount = _moveToReserveAmount;
            }
        }

        bool paidSlash = false;
        if (slashed && stakeInfo.reservedAmount >= BASE_RESERVE_AMOUNT) {
            ApprovedReportInfo memory lastSlashInfo = approvedReportInfos[approvedReportInfos.length - 1];
            payToRenterForSlashing(machineId, stakeInfo, lastSlashInfo.renter, true);
            approvedReportInfos.pop();
            paidSlash = true;
            stateContract.subReserveAmount(msg.sender, machineId, BASE_RESERVE_AMOUNT);
        }

        if (stakeInfo.reservedAmount < BASE_RESERVE_AMOUNT) {
            (uint256 _moveToReserveAmount, uint256 leftAmountCanClaim) =
                tryMoveReserve(machineId, canClaimAmount, stakeInfo);
            canClaimAmount = leftAmountCanClaim;
            moveToReserveAmount = _moveToReserveAmount;
        }

        if (canClaimAmount > 0) {
            rewardToken.transfer(stakeholder, canClaimAmount);
        }
        totalDistributedRewardAmount += canClaimAmount;
        stakeInfo.claimedAmount += canClaimAmount;
        stakeInfo.lastClaimAtTimestamp = currentTimestamp;
        stateContract.addClaimedRewardAmount(msg.sender, machineId, rewardAmount + _dailyReleaseAmount, canClaimAmount);

        if (lockedAmount > 0) {
            machineId2LockedRewardDetail[machineId].totalAmount += lockedAmount;
        }

        emit claimed(stakeholder, machineId, canClaimAmount, moveToReserveAmount, paidSlash);
    }

    function getMachineIdsByStakeholder(address holder) external view returns (string[] memory) {
        return holder2MachineIds[holder];
    }

    function getAllRewardInfo(address holder)
        external
        view
        returns (uint256 availableRewardAmount, uint256 canClaimAmount, uint256 lockedAmount, uint256 claimedAmount)
    {
        string[] memory machineIds = holder2MachineIds[holder];
        for (uint256 i = 0; i < machineIds.length; i++) {
            (uint256 _availableRewardAmount, uint256 _canClaimAmount, uint256 _lockedAmount, uint256 _claimedAmount) =
                getRewardInfo(machineIds[i]);
            availableRewardAmount += _availableRewardAmount;
            canClaimAmount += _canClaimAmount;
            lockedAmount += _lockedAmount;
            claimedAmount += _claimedAmount;
        }
        return (availableRewardAmount, canClaimAmount, lockedAmount, claimedAmount);
    }

    function claimAll() external {
        string[] memory machineIds = holder2MachineIds[msg.sender];
        for (uint256 i = 0; i < machineIds.length; i++) {
            claim(machineIds[i]);
        }
    }

    function claim(string memory machineId) public {
        address stakeholder = msg.sender;
        StakeInfo storage stakeInfo = machineId2StakeInfos[machineId];

        require(getPendingSlashCount(machineId) == 0, "machine should restake and paid slash before claim");

        require(stakeInfo.holder == stakeholder, "not stakeholder");
        require(block.timestamp - stakeInfo.lastClaimAtTimestamp >= 1 days, "last claim less than 1 day");

        _claim(machineId);
    }

    function tryMoveReserve(string memory machineId, uint256 canClaimAmount, StakeInfo storage stakeInfo)
        internal
        returns (uint256 moveToReserveAmount, uint256 leftAmountCanClaim)
    {
        uint256 leftAmountShouldReserve = BASE_RESERVE_AMOUNT - stakeInfo.reservedAmount;
        if (canClaimAmount >= leftAmountShouldReserve) {
            canClaimAmount -= leftAmountShouldReserve;
            moveToReserveAmount = leftAmountShouldReserve;
        } else {
            moveToReserveAmount = canClaimAmount;
            canClaimAmount = 0;
        }

        // the amount should be transfer to reserve
        totalReservedAmount += moveToReserveAmount;
        stakeInfo.reservedAmount += moveToReserveAmount;
        stateContract.addReserveAmount(msg.sender, machineId, moveToReserveAmount);
        return (moveToReserveAmount, canClaimAmount);
    }

    function calculateReleaseReward(string memory machineId)
        public
        view
        returns (uint256 releaseAmount, uint256 lockedAmount)
    {
        LockedRewardDetail storage lockedRewardDetail = machineId2LockedRewardDetail[machineId];
        if (lockedRewardDetail.totalAmount == lockedRewardDetail.claimedAmount) {
            return (0, 0);
        }

        if (block.timestamp > lockedRewardDetail.unlockTime) {
            releaseAmount = lockedRewardDetail.totalAmount - lockedRewardDetail.claimedAmount;
            return (releaseAmount, 0);
        }

        uint256 totalUnlocked =
            (block.timestamp - lockedRewardDetail.lockTime) * lockedRewardDetail.totalAmount / LOCK_PERIOD;
        releaseAmount = totalUnlocked - lockedRewardDetail.claimedAmount;
        return (releaseAmount, lockedRewardDetail.totalAmount - releaseAmount);
    }

    function calculateReleaseRewardAndUpdate(string memory machineId)
        internal
        returns (uint256 releaseAmount, uint256 lockedAmount)
    {
        LockedRewardDetail storage lockedRewardDetail = machineId2LockedRewardDetail[machineId];
        if (lockedRewardDetail.totalAmount == lockedRewardDetail.claimedAmount) {
            return (0, 0);
        }

        if (block.timestamp > lockedRewardDetail.unlockTime) {
            releaseAmount = lockedRewardDetail.totalAmount - lockedRewardDetail.claimedAmount;
            lockedRewardDetail.claimedAmount = lockedRewardDetail.totalAmount;
            return (releaseAmount, 0);
        }

        uint256 totalUnlocked =
            (block.timestamp - lockedRewardDetail.lockTime) * lockedRewardDetail.totalAmount / LOCK_PERIOD;
        releaseAmount = totalUnlocked - lockedRewardDetail.claimedAmount;
        lockedRewardDetail.claimedAmount += releaseAmount;
        return (releaseAmount, lockedRewardDetail.totalAmount - releaseAmount);
    }

    //    function unStakeAndClaim(string calldata machineId) public nonReentrant {
    //        address stakeholder = msg.sender;
    //        StakeInfo storage stakeInfo = machineId2StakeInfos[machineId];
    //        require(stakeInfo.holder == stakeholder, "not stakeholder");
    //        require(stakeInfo.startAtBlockNumber > 0, "staking not found");
    //        require(block.number > stakeInfo.rentEndAt, "staking not ended");
    //
    //        // if (rewardStartAtBlockNumber > 0) {
    //        //     require(
    //        //         (block.number - stakeInfo.startAtBlockNumber) * SECONDS_PER_BLOCK > REWARD_DURATION,
    //        //         "staking reward duration not end yet"
    //        //     );
    //        // }
    //        claim(machineId);
    //        _unStake(machineId, stakeholder);
    //        stateContract.removeMachine(stakeholder, machineId);
    //    }

    function unStake(string calldata machineId) public nonReentrant {
        StakeInfo storage stakeInfo = machineId2StakeInfos[machineId];
        require(dlcClientWalletAddress[msg.sender] || msg.sender == stakeInfo.holder, "not dlc client wallet or owner");
        require(stakeInfo.startAtTimestamp > 0, "staking not found");
        require(block.timestamp >= stakeInfo.endAtTimestamp, "staking not ended");
        _claim(machineId);
        _unStake(machineId, stakeInfo.holder);
    }

    function _unStake(string calldata machineId, address stakeholder) internal {
        StakeInfo storage stakeInfo = machineId2StakeInfos[machineId];
        uint256 reservedAmount = stakeInfo.reservedAmount;

        if (reservedAmount > 0) {
            rewardToken.transfer(stakeholder, reservedAmount);
            stakeInfo.reservedAmount = 0;
            totalReservedAmount = totalReservedAmount > reservedAmount ? totalReservedAmount - reservedAmount : 0;
        }

        stakeInfo.endAtTimestamp = block.timestamp;
        nftToken.safeBatchTransferFrom(
            address(this), stakeholder, stakeInfo.nftTokenIds, stakeInfo.tokenIdBalances, "transfer"
        );
        stakeInfo.nftTokenIds = new uint256[](0);
        stakeInfo.tokenIdBalances = new uint256[](0);
        stakeInfo.nftCount = 0;
        _joinStaking(machineId, 0, 0);
        totalStakedGpuCount -= Math.min(stakeInfo.gpuCount, 0);
        removeStakingMachineFromHolder(stakeholder, machineId);
        stateContract.removeMachine(stakeInfo.holder, machineId);
        emit unStaked(stakeholder, machineId);
    }

    function removeStakingMachineFromHolder(address holder, string memory machineId) internal {
        string[] storage machineIds = holder2MachineIds[holder];
        for (uint256 i = 0; i < machineIds.length; i++) {
            if (keccak256(abi.encodePacked(machineIds[i])) == keccak256(abi.encodePacked(machineId))) {
                machineIds[i] = machineIds[machineIds.length - 1];
                machineIds.pop();
                break;
            }
        }
    }

    function getStakeHolder(string calldata machineId) external view returns (address) {
        StakeInfo memory stakeInfo = machineId2StakeInfos[machineId];
        return stakeInfo.holder;
    }

    function isStaking(string memory machineId) public view returns (bool) {
        StakeInfo storage stakeInfo = machineId2StakeInfos[machineId];
        bool _isStaking = stakeInfo.holder != address(0) && stakeInfo.startAtTimestamp > 0
            && (precompileContract.getOwnerRentEndAt(machineId, stakeInfo.rentId) - rewardStartAtBlockNumber)
                * SECONDS_PER_BLOCK >= REWARD_DURATION && stakeInfo.endAtTimestamp == 0;

        return _isStaking;
    }

    //    function addNFTs(string calldata machineId, uint256[] calldata nftTokenIds) external {
    //        StakeInfo storage stakeInfo = machineId2StakeInfos[machineId];
    //        uint256 oldNftCount = stakeInfo.nftTokenIds.length;
    //        require(stakeInfo.holder == msg.sender, "not stakeholder");
    //        require(oldNftCount + nftTokenIds.length <= MAX_NFTS_PER_MACHINE, "too many nfts, max is 50");
    //        for (uint256 i = 0; i < nftTokenIds.length; i++) {
    //            uint256 tokenID = nftTokenIds[i];
    //            nftToken.transferFrom(msg.sender, address(this), tokenID);
    //            stakeInfo.nftTokenIds.push(tokenID);
    //        }
    //
    //        uint256 newCalcPoint = stakeInfo.calcPoint / oldNftCount * stakeInfo.nftTokenIds.length;
    //        joinStaking(machineId, newCalcPoint, stakeInfo.reservedAmount);
    //
    //        stateContract.addOrUpdateStakeHolder(stakeInfo.holder, machineId, stakeInfo.calcPoint, 0, 0, false);
    //        emit AddNFTs(machineId, nftTokenIds);
    //    }

    function getTotalGPUCountInStaking() public view returns (uint256) {
        return totalStakedGpuCount;
    }

    function getLeftGPUCountToStartReward() public view returns (uint256) {
        return rewardStartGPUThreshold > totalStakedGpuCount ? rewardStartGPUThreshold - totalStakedGpuCount : 0;
    }

    function rentMachine(string calldata machineId) external onlyRentContract {
        StakeInfo storage stakeInfo = machineId2StakeInfos[machineId];
        stakeInfo.isRentedByUser = true;

        uint256 newCalcPoint = (stakeInfo.calcPoint * 13) / 10;
        _joinStaking(machineId, newCalcPoint, stakeInfo.reservedAmount);
        stateContract.addOrUpdateStakeHolder(stakeInfo.holder, machineId, newCalcPoint, 0, false);
        emit RentMachine(machineId);
    }

    function endRentMachine(string calldata machineId) external onlyRentContract {
        StakeInfo storage stakeInfo = machineId2StakeInfos[machineId];
        require(stakeInfo.isRentedByUser, "not rented by user");
        stakeInfo.isRentedByUser = false;

        // 100 blocks
        stakeInfo.nextRenterCanRentAt = 600 + block.timestamp;

        uint256 newCalcPoint = (stakeInfo.calcPoint * 10) / 13;
        _joinStaking(machineId, newCalcPoint, stakeInfo.reservedAmount);
        stateContract.addOrUpdateStakeHolder(stakeInfo.holder, machineId, newCalcPoint, 0, false);

        stateContract.subRentedGPUCount(stakeInfo.holder, machineId);

        emit EndRentMachine(machineId);
    }

    function reportMachineFault(string calldata machineId, address renter) public onlyRentContractOrThis {
        if (!rewardStart()) {
            return;
        }
        if (renter == address(0)) {
            // if renter is not set, it means the machine is not rented by user
            // so we don't need to slash
            return;
        }
        StakeInfo storage stakeInfo = machineId2StakeInfos[machineId];
        emit ReportMachineFault(machineId, renter);
        tryPaySlashOnReport(stakeInfo, machineId, renter);

        _claim(machineId);

        _unStake(machineId, stakeInfo.holder);
    }

    function tryPaySlashOnReport(StakeInfo storage stakeInfo, string memory machineId, address renter) internal {
        if (stakeInfo.reservedAmount >= BASE_RESERVE_AMOUNT) {
            payToRenterForSlashing(machineId, stakeInfo, renter, true);
        } else {
            pendingSlashedMachineId2Renter[machineId].push(ApprovedReportInfo({renter: renter}));
        }
    }

    function getMachineInfoForDBCScan(string memory machineId) external view returns (MachineInfoForDBCScan memory) {
        (, uint256 canClaimAmount, uint256 lockedAmount, uint256 claimedAmount) = getRewardInfo(machineId);
        uint256 totalRewardAmount = canClaimAmount + lockedAmount + claimedAmount;
        bool _isStaking = isStaking(machineId);
        (string memory gpuType, uint256 mem) = precompileContract.getMachineGPUTypeAndMem(machineId);
        MachineInfoForDBCScan memory machineInfo = MachineInfoForDBCScan({
            isStaking: _isStaking,
            gpuType: gpuType,
            gpuCount: _isStaking ? 1 : 0,
            mem: mem,
            projectName: PROJECT_NAME,
            totalRewardAmount: totalRewardAmount,
            lockedRewardAmount: lockedAmount,
            claimedRewardAmount: claimedAmount
        });
        return machineInfo;
    }

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
        )
    {
        StakeInfo memory info = machineId2StakeInfos[machineId];
        uint256 rentEndAtBlock = precompileContract.getOwnerRentEndAt(machineId, info.rentId);
        uint256 rentEndAtTimestamp;
        if (rentEndAtBlock > block.number) {
            rentEndAtTimestamp = (rentEndAtBlock - block.number) * SECONDS_PER_BLOCK + block.timestamp;
        }
        return (
            info.holder,
            info.calcPoint,
            info.startAtTimestamp,
            rentEndAtTimestamp,
            info.nextRenterCanRentAt,
            info.reservedAmount
        );
    }

    function payToRenterForSlashing(
        string memory machineId,
        StakeInfo storage stakeInfo,
        address renter,
        bool alreadyStaked
    ) internal {
        rewardToken.transfer(renter, BASE_RESERVE_AMOUNT);
        if (alreadyStaked) {
            _joinStaking(machineId, stakeInfo.calcPoint, stakeInfo.reservedAmount - BASE_RESERVE_AMOUNT);
        }

        rentContract.paidSlash(stakeInfo.holder, machineId);
        emit PaySlash(machineId, renter, BASE_RESERVE_AMOUNT);
    }

    function getGlobalState() external view returns (uint256, uint256, uint256) {
        return (totalCalcPoint, totalReservedAmount, rewardStartAtTimestamp + REWARD_DURATION);
    }

    function _updateRewardPerCalcPoint() internal {
        rewardsPerCalcPoint = _getUpdatedRewardPerCalcPoint();
    }

    function _getUpdatedRewardPerCalcPoint() internal view returns (RewardCalculatorLib.RewardsPerShare memory) {
        uint256 rewardsPerSeconds = (getDailyRewardAmount()) / 1 days;
        uint256 rewardEndAt = rewardStartAtTimestamp + REWARD_DURATION;
        RewardCalculatorLib.RewardsPerShare memory rewardsPerTokenUpdated = RewardCalculatorLib.getUpdateRewardsPerShare(
            rewardsPerCalcPoint, totalAdjustUnit, rewardsPerSeconds, rewardStartAtTimestamp, rewardEndAt
        );
        return rewardsPerTokenUpdated;
    }

    function _updateMachineRewards(string memory machineId, uint256 machineShares) internal {
        _updateRewardPerCalcPoint();

        RewardCalculatorLib.UserRewards memory machineRewards = machineId2StakeUnitRewards[machineId];
        RewardCalculatorLib.UserRewards memory machineRewardsUpdated =
            RewardCalculatorLib.getUpdateUserRewards(machineRewards, machineShares, rewardsPerCalcPoint);
        machineId2StakeUnitRewards[machineId] = machineRewardsUpdated;
    }

    function _getMachineShares(uint256 calcPoint, uint256 reservedAmount) internal view returns (uint256) {
        return calcPoint
            * toolContract.LnUint256(reservedAmount > BASE_RESERVE_AMOUNT ? reservedAmount : BASE_RESERVE_AMOUNT);
    }

    function _getRewardDetail(uint256 totalRewardAmount)
        internal
        pure
        returns (uint256 canClaimAmount, uint256 lockedAmount)
    {
        uint256 releaseImmediateAmount = totalRewardAmount / 10;
        uint256 releaseLinearLockedAmount = totalRewardAmount - releaseImmediateAmount;
        return (releaseImmediateAmount, releaseLinearLockedAmount);
    }

    function getReward(string memory machineId) external view returns (uint256) {
        return calculateRewards(machineId);
    }

    function getDailyRewardAmount() public view returns (uint256) {
        uint256 remainingSupply = initRewardAmount - totalDistributedRewardAmount;
        if (dailyRewardAmount > remainingSupply) {
            return remainingSupply;
        }
        return dailyRewardAmount;
    }

    function rewardStart() internal view returns (bool) {
        return rewardStartAtTimestamp > 0 && block.timestamp >= rewardStartAtTimestamp;
    }

    //    function updateRewardPerCalcPoint() internal {
    //        if (totalAdjustUnit > 0) {
    //            uint256 timeDelta = rewardStart() ? block.timestamp - lastUpdateTime : 0;
    //            uint256 periodReward = (dailyRewardAmount * timeDelta) / 1 days;
    //            rewardPerUnit += toolContract.safeDiv(periodReward, totalAdjustUnit);
    //        }
    //        lastUpdateTime = block.timestamp;
    //    }

    function _joinStaking(string memory machineId, uint256 calcPoint, uint256 reserveAmount) internal {
        StakeInfo storage stakeInfo = machineId2StakeInfos[machineId];

        uint256 oldLnReserved = toolContract.LnUint256(
            stakeInfo.reservedAmount > BASE_RESERVE_AMOUNT ? stakeInfo.reservedAmount : BASE_RESERVE_AMOUNT
        );

        uint256 machineShares = stakeInfo.calcPoint * oldLnReserved;

        uint256 newLnReserved =
            toolContract.LnUint256(reserveAmount > BASE_RESERVE_AMOUNT ? reserveAmount : BASE_RESERVE_AMOUNT);

        totalAdjustUnit -= stakeInfo.calcPoint * oldLnReserved;
        totalAdjustUnit += calcPoint * newLnReserved;

        // update machine rewards
        _updateMachineRewards(machineId, machineShares);

        totalCalcPoint = totalCalcPoint - stakeInfo.calcPoint + calcPoint;

        stakeInfo.calcPoint = calcPoint;
        if (reserveAmount > stakeInfo.reservedAmount) {
            rewardToken.transferFrom(stakeInfo.holder, address(this), reserveAmount);
        }
        if (reserveAmount != stakeInfo.reservedAmount) {
            totalReservedAmount = totalReservedAmount + reserveAmount - stakeInfo.reservedAmount;
            stakeInfo.reservedAmount = reserveAmount;
        }
    }

    //    function getCurrentRewardRate(uint256 endAtTimestamp) internal view returns (uint256) {
    //        uint256 tempRewardPerUnit = rewardPerUnit;
    //
    //        uint256 rewardStartTime = getRewardStartTime(rewardStartAtTimestamp);
    //
    //        uint256 _lastUpdateTime = rewardStartTime < lastUpdateTime ? lastUpdateTime : rewardStartTime;
    //
    //        uint256 timeDelta = endAtTimestamp - _lastUpdateTime;
    //
    //        if (totalAdjustUnit > 0) {
    //            uint256 periodReward = (dailyRewardAmount * timeDelta) / 1 days;
    //            tempRewardPerUnit += toolContract.safeDiv(periodReward, totalAdjustUnit);
    //        }
    //
    //        return tempRewardPerUnit;
    //    }

    function calculateRewards(string memory machineId) public view returns (uint256) {
        StakeInfo memory stakeInfo = machineId2StakeInfos[machineId];

        uint256 machineShares = _getMachineShares(stakeInfo.calcPoint, stakeInfo.reservedAmount);

        RewardCalculatorLib.UserRewards memory machineRewards = machineId2StakeUnitRewards[machineId];

        RewardCalculatorLib.RewardsPerShare memory currentRewardPerCalcPoint = _getUpdatedRewardPerCalcPoint();
        uint256 rewardAmount = RewardCalculatorLib.calculatePendingUserRewards(
            machineShares, rewardsPerCalcPoint.accumulatedPerShare, currentRewardPerCalcPoint.accumulatedPerShare
        );

        return machineRewards.accumulated + rewardAmount;
    }

    function rewardEnd() public view returns (bool) {
        if (rewardStartAtTimestamp == 0) {
            return false;
        }
        return (block.timestamp > rewardStartAtTimestamp + REWARD_DURATION);
    }

    function getRewardEndAtTimestamp(uint256 stakeEndAtTimestamp) internal view returns (uint256) {
        uint256 rewardEndAt = rewardStartAtTimestamp + REWARD_DURATION;
        uint256 currentTime = block.timestamp;
        if (stakeEndAtTimestamp > rewardEndAt) {
            return rewardEndAt;
        } else if (stakeEndAtTimestamp > currentTime && stakeEndAtTimestamp - currentTime <= 1 hours) {
            return stakeEndAtTimestamp - 1 hours;
        }
        if (stakeEndAtTimestamp != 0 && stakeEndAtTimestamp < currentTime) {
            return stakeEndAtTimestamp;
        }
        return currentTime;
    }

    //    function getRewardsAndUpdateGlobalRewardRate(string memory machineId) public returns (uint256) {
    //        StakeInfo storage stakeInfo = machineId2StakeInfos[machineId];
    //        uint256 endAtTimestamp = precompileContract.getOwnerRentEndAt(machineId, stakeInfo.rentId);
    //        uint256 currentRewardPerUnit = getCurrentRewardRate(getRewardEndAtTimestamp(endAtTimestamp));
    //
    //        uint256 rewards = calculateRewards(machineId, currentRewardPerUnit);
    //
    //        stakeInfo.userRewardDebt = currentRewardPerUnit;
    //        stakeInfo.pendingRewards = 0;
    //        lastUpdateTime = block.timestamp;
    //        rewardPerUnit = currentRewardPerUnit;
    //        return rewards;
    //    }

    function getRewardStartTime(uint256 _rewardStartAtTimestamp) public view returns (uint256) {
        if (_rewardStartAtTimestamp == 0) {
            return 0;
        }
        if (block.timestamp > _rewardStartAtTimestamp) {
            uint256 timeDuration = block.timestamp - _rewardStartAtTimestamp;
            return block.timestamp - timeDuration;
        }

        return block.timestamp + (_rewardStartAtTimestamp - block.timestamp);
    }

    function version() external pure returns (uint256) {
        return 1;
    }
}
