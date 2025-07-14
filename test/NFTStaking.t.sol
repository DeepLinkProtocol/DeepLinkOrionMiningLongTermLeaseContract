// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {Rent} from "../src/rent/Rent.sol";
import {NFTStaking} from "../src/NFTStaking.sol";
import {IPrecompileContract} from "../src/interface/IPrecompileContract.sol";

import {IRewardToken} from "../src/interface/IRewardToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Token} from "./MockRewardToken.sol";
import "./MockERC1155.t.sol";

contract StakingTest is Test {
    Rent public rent;
    NFTStaking public nftStaking;
    IPrecompileContract public precompileContract;
    Token public rewardToken;
    DLCNode public nftToken;

    address owner = makeAddr("owner");
    address admin2 = address(0x02);
    address admin3 = address(0x03);
    address admin4 = address(0x04);
    address admin5 = address(0x05);

    address stakeHolder2 = address(0x06);

    function setUp() public {
        vm.startPrank(owner);
        precompileContract = IPrecompileContract(address(0x11));
        rewardToken = new Token();
        nftToken = new DLCNode(owner);

        ERC1967Proxy proxy1 = new ERC1967Proxy(address(new NFTStaking()), "");
        nftStaking = NFTStaking(address(proxy1));

        ERC1967Proxy proxy = new ERC1967Proxy(address(new Rent()), "");
        rent = Rent(address(proxy));

        NFTStaking(address(proxy1)).initialize(
            owner, address(nftToken), address(rewardToken), address(rent), address(precompileContract), 1
        );
        Rent(address(proxy)).initialize(owner, address(precompileContract), address(nftStaking), address(rewardToken));
        deal(address(rewardToken), address(this), 10000000 * 1e18);
        deal(address(rewardToken), owner, 360000000 * 1e18);
        rewardToken.approve(address(nftStaking), 360000000 * 1e18);
        deal(address(rewardToken), address(nftStaking), 360000000 * 1e18);

        nftStaking.setRewardStartAt(block.timestamp);
        address[] memory admins = new address[](2);
        admins[0] = owner;
        admins[1] = stakeHolder2;
        nftStaking.setDLCClientWallets(admins);
        vm.stopPrank();
    }

    function test_daily_reward() public view {
        assertEq(nftStaking.getDailyRewardAmount(), 6000000 * 1e18);
    }

    function stakeByOwner(string memory machineId, uint256 reserveAmount, uint256 stakeHours, address _owner) public {
        vm.mockCall(
            address(precompileContract),
            abi.encodeWithSelector(precompileContract.getMachineCalcPoint.selector),
            abi.encode(100)
        );

        vm.mockCall(
            address(precompileContract),
            abi.encodeWithSelector(precompileContract.getMachineCPURate.selector),
            abi.encode(3500)
        );

        vm.mockCall(
            address(precompileContract),
            abi.encodeWithSelector(precompileContract.getMachineGPUCount.selector),
            abi.encode(1)
        );

        vm.mockCall(
            address(precompileContract),
            abi.encodeWithSelector(precompileContract.getOwnerRentEndAt.selector),
            abi.encode(60 days / 6)
        );

        vm.mockCall(
            address(precompileContract),
            abi.encodeWithSelector(precompileContract.isMachineOwner.selector),
            abi.encode(true)
        );

        vm.mockCall(
            address(precompileContract),
            abi.encodeWithSelector(precompileContract.getMachineGPUTypeAndMem.selector),
            abi.encode("NVIDIA GeForce RTX 4060 Ti", 16)
        );

        vm.startPrank(_owner);
        dealERC1155(address(nftToken), _owner, 1, 1, false);
        assertEq(nftToken.balanceOf(_owner, 1), 1, "owner erc1155 failed");
        deal(address(rewardToken), _owner, 100000 * 1e18);
        rewardToken.approve(address(nftStaking), reserveAmount);
        nftToken.setApprovalForAll(address(nftStaking), true);

        uint256[] memory nftTokens = new uint256[](1);
        uint256[] memory nftTokensBalance = new uint256[](1);
        nftTokens[0] = 1;
        nftTokensBalance[0] = 1;
        uint256 totalCalcPointBefore = nftStaking.totalCalcPoint();
        nftStaking.stake(_owner, machineId, nftTokens, nftTokensBalance, stakeHours, _owner);
        assertEq(nftToken.balanceOf(_owner, 1), 0, "owner erc1155 failed");
        nftStaking.addDLCToStake(machineId, reserveAmount);
        vm.stopPrank();
        uint256 totalCalcPoint = nftStaking.totalCalcPoint();

        assertEq(totalCalcPoint, totalCalcPointBefore + 100);
    }

    function testStake() public {
        address stakeHolder = owner;
        //        assertEq(nftToken.balanceOf(stakeHolder, 1), 100);
        //        address nftAddr = address(nftToken);
        string memory machineId = "machineId";
        string memory machineId2 = "machineId2";

        //        vm.mockCall(nftAddr, abi.encodeWithSelector(IERC721.transferFrom.selector), abi.encode(true));
        //        vm.mockCall(nftAddr, abi.encodeWithSelector(IERC721.balanceOf.selector), abi.encode(1));

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;
        // staking.stake(machineId, 0, tokenIds, 1);
        stakeByOwner(machineId, 0, 480, stakeHolder);

        passDays(1);

        vm.startPrank(stakeHolder);
        assertLt(
            nftStaking.getReward(machineId),
            nftStaking.getDailyRewardAmount(),
            "get reward lt failed after reward start 1 day 1"
        );
        assertGt(
            nftStaking.getReward(machineId),
            nftStaking.getDailyRewardAmount() - 1 * 1e18,
            "get reward gt failed after reward start 1 day 2"
        );
        vm.stopPrank();

        // staking.stake(machineId2, 0, tokenIds0, 2);

        stakeByOwner(machineId2, 0, 480, stakeHolder2);
        passDays(1);

        uint256 reward2 = nftStaking.getReward(machineId2);
        assertGt(reward2, 0, "machineId2 get reward lt 0  failed after staked 1 day");

        assertLt(
            reward2,
            nftStaking.getDailyRewardAmount() / 2,
            "machineId2 get reward lt staking.getDailyRewardAmount()/2 failed after staked 1 day"
        );

        assertGt(
            nftStaking.getReward(machineId2),
            nftStaking.getDailyRewardAmount() / 2 - 1 * 1e18,
            "machineId2 get reward gt staking.getDailyRewardAmount()/2 - 1 * 1e18 failed after staked 1 day"
        );

        (, uint256 rewardAmountCanClaim, uint256 lockedRewardAmount,) = nftStaking.getRewardInfo(machineId2);
        assertEq(rewardAmountCanClaim, (reward2 * 1) / 10);
        assertEq(lockedRewardAmount, reward2 - (reward2 * 1) / 10);

        passDays(1);
        uint256 reward4 = nftStaking.getReward(machineId2);

        (, uint256 rewardAmountCanClaim0, uint256 lockedRewardAmount0,) = nftStaking.getRewardInfo(machineId2);
        assertEq(rewardAmountCanClaim0, (reward4 * 1) / 10);
        assertEq(lockedRewardAmount0, reward4 - (reward4 * 1) / 10);

        vm.prank(stakeHolder2);
        nftStaking.claim(machineId2);

        reward4 = nftStaking.getReward(machineId2);
        assertEq(reward4, 0, "machineId2 get reward  failed after claim");

        passDays(1);
        (uint256 release, uint256 locked) = nftStaking.calculateReleaseReward(machineId2);
        assertEq(release, ((locked + release) * 3 days / nftStaking.LOCK_PERIOD()), "111");
    }

    // function testClaimTwiceInSuccession() public {
    //     // Create a stake
    //     address stakeHolder = owner;
    //     string memory machineId = "machineIdForDoubleClaim";
    //     stakeByOwner(machineId, 0, 480, stakeHolder);

    //     // Wait for a day to accumulate rewards
    //     passDays(1);

    //     // Get reward information before the first claim
    //     uint256 rewardBeforeFirstClaim = nftStaking.getReward(machineId);
    //     (, uint256 rewardAmountCanClaimBeforeFirst, uint256 lockedRewardAmountBeforeFirst,) =
    //         nftStaking.getRewardInfo(machineId);

    //     // Confirm there are claimable rewards
    //     assertGt(rewardBeforeFirstClaim, 0, "should have reward");
    //     assertGt(rewardAmountCanClaimBeforeFirst, 0, "should have reward");
    //     assertGt(lockedRewardAmountBeforeFirst, 0, "should have reward");

    //     // Record balance before the first claim
    //     uint256 balanceBeforeFirstClaim = rewardToken.balanceOf(stakeHolder);

    //     // First claim of rewards
    //     vm.prank(stakeHolder);
    //     nftStaking.claim(machineId);

    //     // Record balance after the first claim
    //     uint256 balanceAfterFirstClaim = rewardToken.balanceOf(stakeHolder);

    //     // Verify the first claim was successful
    //     assertGt(balanceAfterFirstClaim, balanceBeforeFirstClaim, "first claim should increase balance");

    //     // Get reward information after the first claim
    //     uint256 rewardAfterFirstClaim = nftStaking.getReward(machineId);
    //     (, uint256 rewardAmountCanClaimAfterFirst,,) = nftStaking.getRewardInfo(machineId);

    //     // Verify claimable rewards are zero after the first claim
    //     assertEq(rewardAfterFirstClaim, 0, "after first claim, should have no reward");
    //     assertEq(rewardAmountCanClaimAfterFirst, 0, "after first claim, should have no reward");

    //     // Record balance before the second claim
    //     uint256 balanceBeforeSecondClaim = rewardToken.balanceOf(stakeHolder);

    //     // Immediately perform the second claim
    //     vm.prank(stakeHolder);
    //     nftStaking.claim(machineId);

    //     // Record balance after the second claim
    //     uint256 balanceAfterSecondClaim = rewardToken.balanceOf(stakeHolder);

    //     // Verify the second claim did not increase the balance
    //     assertEq(balanceAfterSecondClaim, balanceBeforeSecondClaim, "second claim should not increase balance");

    //     // Get reward information after the second claim
    //     uint256 rewardAfterSecondClaim = nftStaking.getReward(machineId);

    //     // Verify claimable rewards are still zero after the second claim
    //     assertEq(rewardAfterSecondClaim, 0, "second claim, should have no reward");
    // }

    function testAddNFTsToStake() public {
        // Create initial stake
        address stakeHolder = owner;
        string memory machineId = "machineIdForAddNFTs";
        stakeByOwner(machineId, 0, 480, stakeHolder);

        // Get initial stake info
        NFTStaking.StakeInfo memory initialStakeInfo = nftStaking.getMachineStakeInfo(machineId);
        uint256 initialNFTCount = initialStakeInfo.nftCount;
        uint256 initialCalcPoint = initialStakeInfo.calcPoint;

        // Prepare new NFTs
        uint256[] memory additionalNftTokenIds = new uint256[](1);
        uint256[] memory additionalNftTokenIdBalances = new uint256[](1);
        additionalNftTokenIds[0] = 2; // Use different NFT ID
        additionalNftTokenIdBalances[0] = 1;

        // Provide new NFT to user
        dealERC1155(address(nftToken), stakeHolder, 2, 1, false);
        assertEq(nftToken.balanceOf(stakeHolder, 2), 1, "owner should have the new NFT");

        // Approve NFT for staking contract
        vm.startPrank(stakeHolder);
        nftToken.setApprovalForAll(address(nftStaking), true);

        // Wait some time to accumulate rewards
        passDays(1);

        // Get reward info before adding NFTs
        uint256 rewardBeforeAdd = nftStaking.getReward(machineId);
        assertGt(rewardBeforeAdd, 0, "should have accumulated rewards before adding NFTs");

        // Record balance before adding NFTs
        uint256 balanceBeforeAdd = rewardToken.balanceOf(stakeHolder);

        // Add NFTs to stake
        nftStaking.addNFTsToStake(machineId, additionalNftTokenIds, additionalNftTokenIdBalances);
        vm.stopPrank();

        // Verify NFT transfer
        assertEq(nftToken.balanceOf(stakeHolder, 2), 0, "NFT should be transferred to staking contract");

        // Get updated stake info
        NFTStaking.StakeInfo memory updatedStakeInfo = nftStaking.getMachineStakeInfo(machineId);

        // Verify NFT count increase
        assertEq(updatedStakeInfo.nftCount, initialNFTCount + 1, "NFT count should increase by 1");

        // Verify calc point increase proportionally
        uint256 expectedNewCalcPoint = initialCalcPoint / initialNFTCount * updatedStakeInfo.nftCount;
        assertEq(updatedStakeInfo.calcPoint, expectedNewCalcPoint, "calcPoint should be updated proportionally");

        // Verify NFT arrays are updated
        assertEq(
            updatedStakeInfo.nftTokenIds.length,
            initialStakeInfo.nftTokenIds.length + 1,
            "NFT token IDs array should be extended"
        );
        assertEq(
            updatedStakeInfo.tokenIdBalances.length,
            initialStakeInfo.tokenIdBalances.length + 1,
            "NFT token balances array should be extended"
        );

        // Verify previous rewards are claimed (due to _claim being called)
        uint256 balanceAfterAdd = rewardToken.balanceOf(stakeHolder);
        assertGt(balanceAfterAdd, balanceBeforeAdd, "rewards should be claimed when adding NFTs");

        // Verify reward counter is reset
        uint256 rewardAfterAdd = nftStaking.getReward(machineId);
        assertEq(rewardAfterAdd, 0, "reward counter should be reset after adding NFTs");

        // Wait some time to verify new calc point takes effect
        passDays(1);

        // Get new rewards
        uint256 newReward = nftStaking.getReward(machineId);
        assertGt(newReward, 0, "should accumulate new rewards with updated calcPoint");

        // Verify new reward matches calc point ratio
        uint256 totalCalcPoint = nftStaking.totalCalcPoint();
        uint256 dailyReward = nftStaking.getDailyRewardAmount();
        uint256 expectedReward = (dailyReward * updatedStakeInfo.calcPoint) / totalCalcPoint;

        // Allow 1% error margin
        assertApproxEqRel(
            newReward, expectedReward, 0.01e18, "new reward should match the expected reward based on calcPoint ratio"
        );
    }

    function testUnstakeWithAddedNFTs() public {
        // Initial stake setup
        address stakeHolder = owner;
        string memory machineId = "machineIdForUnstakeTest";
        stakeByOwner(machineId, 100000 ether, 72, stakeHolder);

        // Record initial NFT balance
        uint256 nft1BalanceBefore = nftToken.balanceOf(stakeHolder, 1);

        // Prepare additional NFT
        uint256[] memory newNftTokenIds = new uint256[](1);
        uint256[] memory newNftTokenBalances = new uint256[](1);
        newNftTokenIds[0] = 2;
        newNftTokenBalances[0] = 1;

        // Provide and approve new NFT
        dealERC1155(address(nftToken), stakeHolder, 2, 1, false);
        vm.startPrank(stakeHolder);
        nftToken.setApprovalForAll(address(nftStaking), true);

        // Add NFT to stake
        nftStaking.addNFTsToStake(machineId, newNftTokenIds, newNftTokenBalances);
        vm.stopPrank();

        // Record balance of added NFT
        uint256 nft2BalanceBefore = nftToken.balanceOf(stakeHolder, 2);

        // Wait for staking period to end
        passHours(72);

        // Execute unstake
        vm.prank(stakeHolder);
        nftStaking.unStake(machineId);

        // Verify all NFTs are returned to stake holder
        assertEq(nftToken.balanceOf(stakeHolder, 1), nft1BalanceBefore + 1, "First NFT should be returned");
        assertEq(nftToken.balanceOf(stakeHolder, 2), nft2BalanceBefore + 1, "Added NFT should be returned");

        // Verify stake info is cleared
        NFTStaking.StakeInfo memory stakeInfo = nftStaking.getMachineStakeInfo(machineId);
        assertEq(stakeInfo.nftCount, 0, "Stake info should be cleared");
        assertEq(stakeInfo.calcPoint, 0, "Calc point should be cleared");
    }

    function testUnstake() public {
        address stakeHolder = owner;
        string memory machineId = "machineId";
        stakeByOwner(machineId, 100000, 480, stakeHolder);

        passHours(480);

        vm.startPrank(stakeHolder);
        nftStaking.unStake(machineId);
        vm.stopPrank();
        assertEq(nftToken.balanceOf(stakeHolder, 1), 1, "owner erc1155 failed");
    }

    function claimAfter(string memory machineId, address _owner, uint256 hour, bool shouldGetMore) internal {
        uint256 balance1 = rewardToken.balanceOf(_owner);
        passHours(hour);
        vm.prank(_owner);
        nftStaking.claim(machineId);
        uint256 balance2 = rewardToken.balanceOf(_owner);
        if (shouldGetMore) {
            assertGt(balance2, balance1);
        } else {
            assertEq(balance2, balance1);
        }
    }

    function passHours(uint256 n) public {
        uint256 secondsToAdvance = n * 60 * 60;
        uint256 blocksToAdvance = secondsToAdvance / 6;

        vm.warp(vm.getBlockTimestamp() + secondsToAdvance);
        vm.roll(vm.getBlockNumber() + blocksToAdvance);
    }

    function passDays(uint256 n) public {
        uint256 secondsToAdvance = n * 24 * 60 * 60;
        uint256 blocksToAdvance = secondsToAdvance / nftStaking.SECONDS_PER_BLOCK();

        vm.warp(vm.getBlockTimestamp() + secondsToAdvance);
        vm.roll(vm.getBlockNumber() + blocksToAdvance);
    }

    function passBlocks(uint256 n) public {
        uint256 timeToAdvance = n * nftStaking.SECONDS_PER_BLOCK();

        vm.warp(vm.getBlockTimestamp() + timeToAdvance - 1);
        vm.roll(vm.getBlockNumber() + n - 1);
    }

    function testRewardReceiver() public {
        address rewardReceiver = makeAddr("rewardReceiver");

        string memory machineId = "machineIdWithReceiver";
        stakeByOwnerWithReceiver(machineId, 0, 480, owner, rewardReceiver);

        assertEq(nftStaking.getRewardReceiver(machineId), rewardReceiver, "failed to set reward receiver");

        passDays(1);

        uint256 receiverBalanceBefore = rewardToken.balanceOf(rewardReceiver);
        uint256 ownerBalanceBefore = rewardToken.balanceOf(owner);

        vm.prank(owner);
        nftStaking.claim(machineId);

        uint256 receiverBalanceAfter = rewardToken.balanceOf(rewardReceiver);
        uint256 ownerBalanceAfter = rewardToken.balanceOf(owner);

        assertGt(receiverBalanceAfter, receiverBalanceBefore, "rewardReceiver should receive reward");

        assertEq(ownerBalanceAfter, ownerBalanceBefore, "stakeHolder should not receive reward");
    }

    function testRewardReceiverUnstake() public {
        // Create a reward receiver address
        address rewardReceiver = makeAddr("rewardReceiver");

        // Stake machine with reward receiver and reserve amount
        string memory machineId = "machineIdWithReceiverAndReserve";
        uint256 reserveAmount = 10000 * 1e18;
        stakeByOwnerWithReceiver(machineId, reserveAmount, 480, owner, rewardReceiver);

        // Record initial balances
        uint256 receiverBalanceBefore = rewardToken.balanceOf(rewardReceiver);
        uint256 ownerBalanceBefore = rewardToken.balanceOf(owner);

        // Wait for staking period to end
        passHours(480);

        // Claim any pending rewards before unstaking to isolate the reserve amount test
        vm.prank(owner);
        nftStaking.claim(machineId);

        // Reset balances after claiming
        receiverBalanceBefore = rewardToken.balanceOf(rewardReceiver);
        ownerBalanceBefore = rewardToken.balanceOf(owner);

        // Unstake

        (uint256 releasedFromLockedBefere,) = nftStaking.calculateReleaseReward(machineId);

        vm.prank(owner);
        nftStaking.unStake(machineId);

        // Verify balances
        uint256 receiverBalanceAfter = rewardToken.balanceOf(rewardReceiver);
        uint256 ownerBalanceAfter = rewardToken.balanceOf(owner);

        // Reward receiver should receive exactly the reserve amount
        assertEq(
            receiverBalanceAfter,
            receiverBalanceBefore + reserveAmount + releasedFromLockedBefere,
            "rewardReceiver should receive reserveAmount"
        );

        // Stake holder should not receive any tokens
        assertEq(ownerBalanceAfter, ownerBalanceBefore, "stakeHolder should not receive reward");

        // NFT should be returned to stake holder
        assertEq(nftToken.balanceOf(owner, 1), 1, "NFT should be transferred back to stakeHolder");
    }

    function stakeByOwnerWithReceiver(
        string memory machineId,
        uint256 reserveAmount,
        uint256 stakeHours,
        address _owner,
        address _rewardReceiver
    ) public {
        vm.mockCall(
            address(precompileContract),
            abi.encodeWithSelector(precompileContract.getMachineCalcPoint.selector),
            abi.encode(100)
        );

        vm.mockCall(
            address(precompileContract),
            abi.encodeWithSelector(precompileContract.getMachineCPURate.selector),
            abi.encode(3500)
        );

        vm.mockCall(
            address(precompileContract),
            abi.encodeWithSelector(precompileContract.getMachineGPUCount.selector),
            abi.encode(1)
        );

        vm.mockCall(
            address(precompileContract),
            abi.encodeWithSelector(precompileContract.getOwnerRentEndAt.selector),
            abi.encode(60 days / 6)
        );

        vm.mockCall(
            address(precompileContract),
            abi.encodeWithSelector(precompileContract.isMachineOwner.selector),
            abi.encode(true)
        );

        vm.mockCall(
            address(precompileContract),
            abi.encodeWithSelector(precompileContract.getMachineGPUTypeAndMem.selector),
            abi.encode("NVIDIA GeForce RTX 4060 Ti", 16)
        );

        vm.startPrank(_owner);
        dealERC1155(address(nftToken), _owner, 1, 1, false);
        assertEq(nftToken.balanceOf(_owner, 1), 1, "owner erc1155 failed");
        deal(address(rewardToken), _owner, 100000 * 1e18);
        rewardToken.approve(address(nftStaking), reserveAmount);
        nftToken.setApprovalForAll(address(nftStaking), true);

        uint256[] memory nftTokens = new uint256[](1);
        uint256[] memory nftTokensBalance = new uint256[](1);
        nftTokens[0] = 1;
        nftTokensBalance[0] = 1;
        uint256 totalCalcPointBefore = nftStaking.totalCalcPoint();

        nftStaking.stake(_owner, machineId, nftTokens, nftTokensBalance, stakeHours, _rewardReceiver);

        assertEq(nftToken.balanceOf(_owner, 1), 0, "owner erc1155 failed");
        nftStaking.addDLCToStake(machineId, reserveAmount);
        vm.stopPrank();
        uint256 totalCalcPoint = nftStaking.totalCalcPoint();

        assertEq(totalCalcPoint, totalCalcPointBefore + 100);
    }

    // function testClaimTwiceInSuccession() public {
    //     // Create a stake
    //     address stakeHolder = owner;
    //     string memory machineId = "machineIdForDoubleClaim";
    //     stakeByOwner(machineId, 0, 480, stakeHolder);

    //     // Wait for a day to accumulate rewards
    //     passDays(1);

    //     // Get reward information before the first claim
    //     uint256 rewardBeforeFirstClaim = nftStaking.getReward(machineId);
    //     (, uint256 rewardAmountCanClaimBeforeFirst, uint256 lockedRewardAmountBeforeFirst,) =
    //         nftStaking.getRewardInfo(machineId);

    //     // Confirm there are claimable rewards
    //     assertGt(rewardBeforeFirstClaim, 0, "should have reward");
    //     assertGt(rewardAmountCanClaimBeforeFirst, 0, "should have reward");
    //     assertGt(lockedRewardAmountBeforeFirst, 0, "should have reward");

    //     // Record balance before the first claim
    //     uint256 balanceBeforeFirstClaim = rewardToken.balanceOf(stakeHolder);

    //     // First claim of rewards
    //     vm.prank(stakeHolder);
    //     nftStaking.claim(machineId);

    //     // Record balance after the first claim
    //     uint256 balanceAfterFirstClaim = rewardToken.balanceOf(stakeHolder);

    //     // Verify the first claim was successful
    //     assertGt(balanceAfterFirstClaim, balanceBeforeFirstClaim, "first claim should increase balance");

    //     // Get reward information after the first claim
    //     uint256 rewardAfterFirstClaim = nftStaking.getReward(machineId);
    //     (, uint256 rewardAmountCanClaimAfterFirst,,) = nftStaking.getRewardInfo(machineId);

    //     // Verify claimable rewards are zero after the first claim
    //     assertEq(rewardAfterFirstClaim, 0, "after first claim, should have no reward");
    //     assertEq(rewardAmountCanClaimAfterFirst, 0, "after first claim, should have no reward");

    //     // Record balance before the second claim
    //     uint256 balanceBeforeSecondClaim = rewardToken.balanceOf(stakeHolder);

    //     // Immediately perform the second claim
    //     vm.prank(stakeHolder);
    //     nftStaking.claim(machineId);

    //     // Record balance after the second claim
    //     uint256 balanceAfterSecondClaim = rewardToken.balanceOf(stakeHolder);

    //     // Verify the second claim did not increase the balance
    //     assertEq(balanceAfterSecondClaim, balanceBeforeSecondClaim, "second claim should not increase balance");

    //     // Get reward information after the second claim
    //     uint256 rewardAfterSecondClaim = nftStaking.getReward(machineId);

    //     // Verify claimable rewards are still zero after the second claim
    //     assertEq(rewardAfterSecondClaim, 0, "second claim, should have no reward");
    // }

    function testLockedRewardFullClaimAfterLockPeriod() public {
        // Test if a user can claim all locked rewards after the lock period ends
        address stakeHolder = owner;
        string memory machineId = "machineId";

        // Setup staking
        stakeByOwner(machineId, 100000 ether, 72, stakeHolder);

        // Set reward start time to enable rewards
        vm.prank(owner);
        nftStaking.setRewardStartAt(block.timestamp);

        // Pass some time to accumulate rewards
        passHours(24);

        // Check initial rewards
        (uint256 totalReward, uint256 canClaimNow, uint256 lockedAmount,) = nftStaking.getRewardInfo(machineId);
        assertGt(totalReward, 0, "Should have accumulated some rewards");
        assertGt(lockedAmount, 0, "Should have some locked rewards");

        // Claim rewards first time - this will lock 90% of rewards
        vm.startPrank(stakeHolder);
        uint256 balanceBefore = rewardToken.balanceOf(stakeHolder);
        nftStaking.claim(machineId);
        uint256 balanceAfter = rewardToken.balanceOf(stakeHolder);
        vm.stopPrank();

        // Verify immediate claim (10% of rewards) - 使用近似比较而不是精确比较
        assertEq(balanceAfter - balanceBefore, canClaimNow, "Should have claimed immediate rewards");

        // Get locked reward details
        (,, uint256 stillLockedAmount,) = nftStaking.getRewardInfo(machineId);
        assertGt(stillLockedAmount, 0, "Should still have locked rewards");

        // Fast forward to after lock period (180 days)
        vm.warp(block.timestamp + nftStaking.LOCK_PERIOD() + 1);

        // uint256 leftLocked = total-claimed;

        // Check rewards after lock period
        (, uint256 newCanClaimNow, uint256 newLockedAmount,) = nftStaking.getRewardInfo(machineId);

        // All previously locked rewards should now be claimable
        assertGt(newLockedAmount, 0, "Should have new locked rewards after lock period");
        assertGt(newCanClaimNow, 0, "Should have claimable rewards after lock period");

        // Claim all rewards after lock period
        vm.startPrank(stakeHolder);
        uint256 balanceBeforeFinal = rewardToken.balanceOf(stakeHolder);
        nftStaking.claim(machineId);
        uint256 balanceAfterFinal = rewardToken.balanceOf(stakeHolder);
        vm.stopPrank();

        assertApproxEqRel(
            balanceAfterFinal - balanceBeforeFinal, newCanClaimNow, 0.01e18, "Should have claimed all unlocked rewards"
        );

        // Verify no more locked rewards
        (, uint256 finalCanClaimNow, uint256 finalLockedAmount,) = nftStaking.getRewardInfo(machineId);
        assertGt(finalCanClaimNow, 0, "Should have new rewards after claiming");
        assertEq(finalLockedAmount, 0, "Should have no locked rewards after claiming");

        (uint256 total, uint256 startTime, uint256 endTime, uint256 claimed) =
            nftStaking.machineId2LockedRewardDetail(machineId);
        assertEq(endTime - startTime, nftStaking.LOCK_PERIOD());
        uint256 left = total - claimed;
        vm.startPrank(stakeHolder);
        uint256 balanceBeforeFinal1 = rewardToken.balanceOf(stakeHolder);
        nftStaking.claim(machineId);
        uint256 balanceAfterFinal1 = rewardToken.balanceOf(stakeHolder);
        vm.stopPrank();
        assertEq(left, balanceAfterFinal1 - balanceBeforeFinal1);

        (uint256 totalFinal,,, uint256 claimedFinal) = nftStaking.machineId2LockedRewardDetail(machineId);

        assertEq(totalFinal, claimedFinal);
    }

    function testAddNFTsToStakeRewardIncreaseWithTwoMachines() public {
        // Setup two machines with different stakeholders
        address stakeHolder = owner;
        string memory machineIdA = "machineIdForRewardA";
        string memory machineIdB = "machineIdForRewardB";

        // Stake both machines
        stakeByOwner(machineIdA, 0, 480, stakeHolder);
        stakeByOwner(machineIdB, 0, 480, stakeHolder2);

        // Wait for rewards to accumulate
        passDays(1);

        // Record initial rewards for machine A
        uint256 initialRewardA = nftStaking.getReward(machineIdA);
        assertGt(initialRewardA, 0, "Machine A should have initial rewards");

        // Record initial rewards for machine B
        uint256 initialRewardB = nftStaking.getReward(machineIdB);
        assertGt(initialRewardB, 0, "Machine B should have initial rewards");

        // Claim rewards for machine B before adding NFT to machine A
        vm.prank(stakeHolder2);
        nftStaking.claim(machineIdB);

        // Print reward increase
        // Prepare additional NFT for machine A
        uint256[] memory newNftTokenIds = new uint256[](1);
        uint256[] memory newNftTokenBalances = new uint256[](1);
        newNftTokenIds[0] = 2;
        newNftTokenBalances[0] = 1;

        // Provide and approve new NFT
        dealERC1155(address(nftToken), stakeHolder, 2, 1, false);
        vm.startPrank(stakeHolder);
        nftToken.setApprovalForAll(address(nftStaking), true);

        // Add NFT to machine A
        nftStaking.addNFTsToStake(machineIdA, newNftTokenIds, newNftTokenBalances);
        vm.stopPrank();

        // Wait for new rewards to accumulate
        passDays(1);

        // Get new rewards
        uint256 newRewardA = nftStaking.getReward(machineIdA);
        uint256 newRewardB = nftStaking.getReward(machineIdB);

        // 打印奖励增加情况
        console.log("Machine A initial reward:", initialRewardA);
        console.log("Machine A new reward:", newRewardA);
        console.log("Machine A reward increase:", newRewardA - initialRewardA);
        console.log("Machine A reward increase percentage:", (newRewardA * 100) / initialRewardA, "%");

        console.log("Machine B initial reward:", initialRewardB);
        console.log("Machine B new reward:", newRewardB);
        console.log("Machine B reward decrease:", initialRewardB - newRewardB);
        console.log("Machine B reward decrease percentage:", (newRewardB * 100) / initialRewardB, "%");

        // Verify machine A's reward increased
        assertGt(newRewardA, initialRewardA, "Machine A's reward should increase after adding NFT");

        // Verify machine B's reward decreased due to increased total stake
        assertLt(newRewardB, initialRewardB, "Machine B's reward should decrease due to increased total stake");

        // Calculate and verify the reward ratio
        uint256 totalCalcPoint = nftStaking.totalCalcPoint();
        uint256 machineACalcPoint = nftStaking.getMachineStakeInfo(machineIdA).calcPoint;
        uint256 dailyReward = nftStaking.getDailyRewardAmount();

        uint256 expectedRewardA = (dailyReward * machineACalcPoint) / totalCalcPoint;
        assertApproxEqRel(newRewardA, expectedRewardA, 0.01e18, "Machine A's reward should match expected calculation");
    }
}
