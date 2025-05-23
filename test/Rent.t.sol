// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// import {Test, console} from "forge-std/Test.sol";
// import {Rent} from "../src/rent/Rent.sol";
// import {NFTStaking} from "../src/NFTStaking.sol";
// import {IPrecompileContract} from "../src/interface/IPrecompileContract.sol";
// import {ToolLib} from "../src/library/ToolLib.sol";
// import {IRewardToken} from "../src/interface/IRewardToken.sol";
// import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
// import {Token} from "./MockRewardToken.sol";
// import "./MockERC1155.t.sol";

// contract RentTest is Test {
//     Rent public rent;
//     NFTStaking public nftStaking;
//     IPrecompileContract public precompileContract;
//     Token public rewardToken;
//     DLCNode public nftToken;

//     address owner = address(0x01);
//     address admin2 = address(0x02);
//     address admin3 = address(0x03);
//     address admin4 = address(0x04);
//     address admin5 = address(0x05);

//     function setUp() public {
//         vm.startPrank(owner);
//         precompileContract = IPrecompileContract(address(0x11));
//         rewardToken = new Token();
//         nftToken = new DLCNode(owner);

//         ERC1967Proxy proxy1 = new ERC1967Proxy(address(new NFTStaking()), "");
//         nftStaking = NFTStaking(address(proxy1));

//         ERC1967Proxy proxy = new ERC1967Proxy(address(new Rent()), "");
//         rent = Rent(address(proxy));

//         NFTStaking(address(proxy1)).initialize(
//             owner, address(nftToken), address(rewardToken), address(rent), address(precompileContract), 1
//         );
//         Rent(address(proxy)).initialize(owner, address(precompileContract), address(nftStaking), address(rewardToken));
//         deal(address(rewardToken), address(this), 10000000 * 1e18);
//         deal(address(rewardToken), owner, 360000000 * 1e18);
//         rewardToken.approve(address(nftStaking), 360000000 * 1e18);
//         deal(address(rewardToken), address(nftStaking), 360000000 * 1e18);
//         nftStaking.setRewardStartAt(block.timestamp);
//         address[] memory admins = new address[](1);
//         admins[0] = owner;

//         nftStaking.setDLCClientWallets(admins);

//         vm.stopPrank();
//     }

//     function testRentMachine() public {
//         string memory machineId = "machineId";
//         stakeByOwner(machineId, 0, 2);

//         uint256 totalCalcPointBeforeRent = nftStaking.totalCalcPoint();
//         uint256 totalAdjustUnitBeforeRent = nftStaking.totalAdjustUnit();

//         uint256 rentSeconds = 1 hours;
//         uint256 rentFee = rent.getMachinePrice(machineId, rentSeconds);

//         rentMachine(machineId, address(this), rentSeconds, rentFee);

//         // Assert
//         assertEq(rent.getRenter(machineId), address(this));
//         assertEq(rent.canRent(machineId), false);
//         assertEq(rent.isRented(machineId), true);
//         assertEq(rent.totalBurnedAmount(), rentFee);
//         assertEq(rent.getBurnedRentFeeByStakeHolder(owner), rentFee);

//         assertEq(nftStaking.getTotalDlcNftStakingBurnedRentFee(), rentFee);
//         assertEq(nftStaking.getRentedGPUCountInDlcNftStaking(), 1);

//         address[] memory admins = new address[](1);
//         admins[0] = owner;

//         uint256 totalCalcPointInRent = nftStaking.totalCalcPoint();
//         uint256 totalAdjustUnitInRent = nftStaking.totalAdjustUnit();

//         assertEq(totalCalcPointInRent, totalCalcPointBeforeRent * 13 / 10);
//         assertGt(totalAdjustUnitInRent, totalAdjustUnitBeforeRent);

//         // end machine
//         vm.startPrank(admins[0]);
//         vm.expectRevert(abi.encodeWithSelector(Rent.RentNotEnd.selector));
//         rent.endRentMachine(machineId);

//         passHours(1);
//         rent.endRentMachine(machineId);

//         uint256 totalCalcPointAfterRent = nftStaking.totalCalcPoint();
//         uint256 totalAdjustUnitAfterRent = nftStaking.totalAdjustUnit();

//         assertEq(totalCalcPointAfterRent, totalCalcPointBeforeRent);
//         assertEq(totalAdjustUnitAfterRent, totalAdjustUnitBeforeRent);
//         vm.stopPrank();

//         (NFTStaking.StakeHolder[] memory topStakeHolders, uint256 total) = nftStaking.getTopStakeHolders(0, 10);
//         assertEq(total, 1);
//         assertEq(topStakeHolders.length, 1);
//         assertEq(topStakeHolders[0].holder, owner);
//         assertEq(topStakeHolders[0].rentedGPUCount, 0);
//         assertEq(topStakeHolders[0].burnedRentFee, rentFee);
//         assertEq(topStakeHolders[0].totalCalcPoint, 100);
//         assertEq(topStakeHolders[0].totalGPUCount, 1);
//     }

//     function testApproveMachineFaultReporting() public {
//         // Arrange
//         string memory machineId = "machineId";
//         stakeByOwner(machineId, 0, 2);

//         address renter = address(this);

//         uint256 rentSeconds = 1 hours;
//         uint256 rentFee = 1000 * 1e18;
//         rentMachine(machineId, renter, rentSeconds, rentFee);

//         uint256 balanceBeforeReport = rewardToken.balanceOf(address(this));

//         reportMachineFault(machineId, renter);

//         uint256 balanceAfterReport = rewardToken.balanceOf(renter);

//         assertEq(balanceAfterReport, balanceBeforeReport - rent.REPORT_RESERVE_AMOUNT());

//         approveReport(machineId, renter);

//         uint256 balanceAfterAdminApprove = rewardToken.balanceOf(renter);
//         assertEq(balanceAfterAdminApprove, balanceBeforeReport);

//         // after approve, pendingSlashMachineId2ApprovedCount should be delete
//         assertEq(rent.pendingSlashMachineId2ApprovedCount(machineId), 0);
//     }

//     function testRejectMachineFaultReporting() public {
//         string memory machineId = "machineId";
//         stakeByOwner(machineId, 0, 2);
//         address renter = address(this);

//         uint256 rentSeconds = 1 hours;
//         uint256 rentFee = 1000 * 1e18;
//         rentMachine(machineId, renter, rentSeconds, rentFee);

//         uint256 balanceBeforeReport = rewardToken.balanceOf(address(this));

//         reportMachineFault(machineId, renter);

//         uint256 balanceAfterReport = rewardToken.balanceOf(renter);

//         assertEq(balanceAfterReport, balanceBeforeReport - rent.REPORT_RESERVE_AMOUNT());

//         rejectReport(machineId);

//         uint256 balanceAfterAdminRefused = rewardToken.balanceOf(address(this));
//         assertEq(balanceAfterAdminRefused, balanceBeforeReport - rent.REPORT_RESERVE_AMOUNT());

//         assertEq(rent.pendingSlashMachineId2RefuseCount(machineId), 0);
//     }

//     function testSlashForStakeHolderWithStakeTokenAfterReportApprove() public {
//         string memory machineId = "machineId";
//         uint256 stakeTokenAmount = 20000 * 1e18;
//         stakeByOwner(machineId, stakeTokenAmount, 2);

//         //        vm.startPrank(owner);
//         //        nftStaking.claim(machineId);
//         //        vm.stopPrank();

//         assertEq(nftToken.balanceOf(address(nftStaking), 1), 1);

//         address renter = address(this);

//         uint256 rentSeconds = 1 hours;
//         uint256 rentFee = 1000 * 1e18;
//         rentMachine(machineId, renter, rentSeconds, rentFee);
//         assertEq(nftStaking.totalReservedAmount(), stakeTokenAmount);
//         uint256 ownerBalanceBeforeSlash = rewardToken.balanceOf(owner);
//         reportMachineFault(machineId, renter);
//         uint256 renterBalanceBeforeApprove = rewardToken.balanceOf(renter);
//         approveReport(machineId, renter);
//         uint256 renterBalanceAfterApprove = rewardToken.balanceOf(renter);
//         uint256 ownerBalanceAfterSlash = rewardToken.balanceOf(owner);
//         assertEq(ownerBalanceAfterSlash, ownerBalanceBeforeSlash + stakeTokenAmount - nftStaking.BASE_RESERVE_AMOUNT());
//         assertEq(nftToken.balanceOf(address(owner), 1), 1);

//         assertEq(
//             renterBalanceAfterApprove,
//             renterBalanceBeforeApprove + nftStaking.BASE_RESERVE_AMOUNT() + rent.REPORT_RESERVE_AMOUNT()
//         );
//         assertEq(nftStaking.totalReservedAmount(), 0);
//         (,,, uint256 endAt,, uint256 _stakeTokenAmount,,,,,,) = nftStaking.machineId2StakeInfos(machineId);
//         assertEq(_stakeTokenAmount, 0);
//         assertEq(endAt, block.timestamp);
//         assertEq(nftStaking.isStaking(machineId), false);

//         passHours(24);
//         //        uint256 balance1OfOwner = rewardToken.balanceOf(owner);
//         //        vm.startPrank(owner);
//         //        nftStaking.claim(machineId);
//         //
//         //        uint256 balance2OfOwner = rewardToken.balanceOf(owner);
//         //        vm.stopPrank();
//         //        assertGt(balance2OfOwner,balance1OfOwner);
//         //
//         //        (uint256 amount,uint256 unlockTime) = nftStaking.machineId2LockedRewardDetails(machineId,0);
//         //        assertGt(amount,0);
//         //        assertEq(unlockTime,block.timestamp + 180 days);

//         stakeByOwner(machineId, 0, 2);
//     }

//     function testSlashForStakeHolderWithoutStakeTokenAfterReportApprove() public {
//         string memory machineId = "machineId";
//         uint256 stakeTokenAmount = 0;
//         stakeByOwner(machineId, stakeTokenAmount, 2);
//         assertEq(nftStaking.totalReservedAmount(), stakeTokenAmount);

//         assertEq(nftToken.balanceOf(address(nftStaking), 1), 1);

//         address renter = address(this);

//         uint256 rentSeconds = 1 hours;
//         uint256 rentFee = 1000 * 1e18;

//         rentMachine(machineId, renter, rentSeconds, rentFee);
//         assertEq(nftStaking.totalReservedAmount(), stakeTokenAmount);
//         uint256 ownerBalanceBeforeSlash = rewardToken.balanceOf(owner);

//         reportMachineFault(machineId, renter);
//         uint256 renterBalanceBeforeApprove = rewardToken.balanceOf(renter);
//         approveReport(machineId, renter);
//         uint256 renterBalanceAfterApprove = rewardToken.balanceOf(renter);
//         uint256 ownerBalanceAfterSlash = rewardToken.balanceOf(owner);

//         assertGt(ownerBalanceAfterSlash, ownerBalanceBeforeSlash + stakeTokenAmount - nftStaking.BASE_RESERVE_AMOUNT());

//         assertEq(nftToken.balanceOf(address(owner), 1), 1);

//         assertEq(renterBalanceAfterApprove, renterBalanceBeforeApprove + rent.REPORT_RESERVE_AMOUNT());

//         assertEq(nftStaking.totalReservedAmount(), 0);
//         (,,, uint256 endAt,, uint256 _stakeTokenAmount,,,,,,) = nftStaking.machineId2StakeInfos(machineId);
//         assertEq(_stakeTokenAmount, 0);
//         assertEq(endAt, block.timestamp);
//         assertEq(nftStaking.isStaking(machineId), false);

//         //        (uint256 amount,uint256 unlockTime) = nftStaking.machineId2LockedRewardDetails(machineId,0);
//         //        assertGt(amount,0);
//         //        assertEq(unlockTime,block.timestamp + 180 days);

//         passHours(24);
//         //        uint256 balance1OfOwner = rewardToken.balanceOf(owner);
//         //        vm.startPrank(owner);
//         //        nftStaking.claim(machineId);
//         //        uint256 balance2OfOwner = rewardToken.balanceOf(owner);
//         //        vm.stopPrank();
//         //        assertGt(balance2OfOwner,balance1OfOwner);

//         stakeByOwner(machineId, nftStaking.BASE_RESERVE_AMOUNT(), 2);

//         (,,,,, uint256 _stakeTokenAmount1,,,,,,) = nftStaking.machineId2StakeInfos(machineId);
//         assertEq(_stakeTokenAmount1, 0);
//     }

//     function passHours(uint256 n) public {
//         uint256 secondsToAdvance = n * 60 * 60;
//         uint256 blocksToAdvance = secondsToAdvance / 6;

//         vm.warp(vm.getBlockTimestamp() + secondsToAdvance);
//         vm.roll(vm.getBlockNumber() + blocksToAdvance);
//     }

//     function rentMachine(string memory machineId, address renter, uint256 rentSeconds, uint256 rentFee) public {
//         vm.startPrank(renter);
//         rewardToken.approve(address(rent), rentFee);
//         rent.rentMachine(machineId, rentSeconds);
//         vm.stopPrank();
//     }

//     function reportMachineFault(string memory machineId, address renter) public {
//         vm.startPrank(renter);
//         uint256 balanceBeforeReport = rewardToken.balanceOf(renter);

//         rewardToken.approve(address(rent), rent.REPORT_RESERVE_AMOUNT());
//         rent.reportMachineFault(machineId, rent.REPORT_RESERVE_AMOUNT());
//         vm.stopPrank();

//         uint256 balanceAfterReport = rewardToken.balanceOf(renter);

//         assertEq(balanceAfterReport, balanceBeforeReport - rent.REPORT_RESERVE_AMOUNT(), "reportMachineFault failed");
//     }

//     function approveReport(string memory machineId, address renter) public {
//         address[] memory admins = new address[](5);
//         admins[0] = renter;
//         admins[1] = owner;
//         admins[2] = admin3;
//         admins[3] = admin4;
//         admins[4] = admin5;

//         vm.prank(owner);
//         rent.setAdminsToApproveMachineFaultReporting(admins);
//         rent.approveMachineFaultReporting(machineId);
//         assertEq(rent.pendingSlashMachineId2ApprovedCount(machineId), 1);

//         vm.prank(renter);
//         rent.approveMachineFaultReporting(machineId);

//         vm.prank(admin3);
//         rent.approveMachineFaultReporting(machineId);
//     }

//     function rejectReport(string memory machineId) public {
//         address[] memory admins = new address[](5);
//         admins[0] = owner;
//         admins[1] = admin2;
//         admins[2] = admin3;
//         admins[3] = admin4;
//         admins[4] = admin5;

//         uint256 adminBalanceBeforeReject = rewardToken.balanceOf(admin2);

//         vm.prank(owner);
//         rent.setAdminsToApproveMachineFaultReporting(admins);
//         vm.prank(owner);
//         rent.rejectMachineFaultReporting(machineId);
//         assertEq(rent.pendingSlashMachineId2RefuseCount(machineId), 1);

//         vm.prank(admin2);
//         rent.rejectMachineFaultReporting(machineId);

//         vm.prank(admin3);
//         rent.rejectMachineFaultReporting(machineId);
//         uint256 adminBalanceAfterReject = rewardToken.balanceOf(admin2);

//         assertEq(adminBalanceAfterReject, adminBalanceBeforeReject + rent.REPORT_RESERVE_AMOUNT() / admins.length);
//     }

//     function stakeByOwner(string memory machineId, uint256 reserveAmount, uint256 stakeHours) public {
//         vm.mockCall(
//             address(precompileContract),
//             abi.encodeWithSelector(precompileContract.getMachineCalcPoint.selector),
//             abi.encode(100)
//         );

//         vm.mockCall(
//             address(precompileContract),
//             abi.encodeWithSelector(precompileContract.getMachineCPURate.selector),
//             abi.encode(3500)
//         );

//         vm.mockCall(
//             address(precompileContract),
//             abi.encodeWithSelector(precompileContract.getMachineGPUCount.selector),
//             abi.encode(1)
//         );

//         vm.mockCall(
//             address(precompileContract),
//             abi.encodeWithSelector(precompileContract.getOwnerRentEndAt.selector),
//             abi.encode(60 days / 6)
//         );

//         vm.mockCall(
//             address(precompileContract),
//             abi.encodeWithSelector(precompileContract.isMachineOwner.selector),
//             abi.encode(true)
//         );

//         vm.mockCall(
//             address(precompileContract),
//             abi.encodeWithSelector(precompileContract.getMachineGPUTypeAndMem.selector),
//             abi.encode("NVIDIA GeForce RTX 4060 Ti", 16)
//         );

//         vm.startPrank(owner);
//         dealERC1155(address(nftToken), owner, 1, 1, false);
//         assertEq(nftToken.balanceOf(owner, 1), 1, "owner erc1155 failed");
//         deal(address(rewardToken), owner, 100000 * 1e18);
//         rewardToken.approve(address(nftStaking), reserveAmount);
//         nftToken.setApprovalForAll(address(nftStaking), true);

//         uint256[] memory nftTokens = new uint256[](1);
//         uint256[] memory nftTokensBalance = new uint256[](1);
//         nftTokens[0] = 1;
//         nftTokensBalance[0] = 1;
//         nftStaking.stake(owner, machineId, nftTokens, nftTokensBalance, stakeHours,owner);
//         nftStaking.addDLCToStake(machineId, reserveAmount);
//         vm.stopPrank();
//         uint256 totalCalcPointBeforeRent = nftStaking.totalCalcPoint();

//         assertEq(totalCalcPointBeforeRent, 100);
//     }

//     function testGetMachinePrice() public {
//         string memory machineId = "machineId";

//         vm.mockCall(
//             address(nftStaking.precompileContract()),
//             abi.encodeWithSelector(precompileContract.getMachineCalcPoint.selector),
//             abi.encode(987600)
//         );

//         vm.mockCall(
//             address(nftStaking.precompileContract()),
//             abi.encodeWithSelector(precompileContract.getMachineGPUTypeAndMem.selector),
//             abi.encode("NVIDIA GeForce RTX 4060 Ti", 16)
//         );

//         vm.mockCall(
//             address(precompileContract),
//             abi.encodeWithSelector(precompileContract.getMachineCPURate.selector),
//             abi.encode(3500)
//         );

//         vm.mockCall(
//             address(precompileContract),
//             abi.encodeWithSelector(precompileContract.getMachineGPUCount.selector),
//             abi.encode(1)
//         );

//         vm.mockCall(
//             address(precompileContract),
//             abi.encodeWithSelector(precompileContract.getOwnerRentEndAt.selector),
//             abi.encode(60 days / 6)
//         );

//         vm.mockCall(
//             address(precompileContract),
//             abi.encodeWithSelector(precompileContract.isMachineOwner.selector),
//             abi.encode(true)
//         );

//         vm.startPrank(owner);
//         if (!nftStaking.dlcClientWalletAddress(owner)) {
//             address[] memory addrs = new address[](1);
//             addrs[0] = owner;
//             nftStaking.setDLCClientWallets(addrs);
//         }

//         dealERC1155(address(nftToken), owner, 1, 1, false);
//         assertEq(nftToken.balanceOf(owner, 1), 1, "owner erc1155 failed");
//         nftToken.setApprovalForAll(address(nftStaking), true);

//         uint256[] memory nftTokens = new uint256[](1);
//         uint256[] memory nftTokensBalance = new uint256[](1);
//         nftTokens[0] = 1;
//         nftTokensBalance[0] = 1;
//         nftStaking.stake(owner, machineId, nftTokens, nftTokensBalance, 2,owner);

//         uint256 fee = rent.getMachinePrice(machineId, 3600);
//         console.log("fee: {}", fee);
//         assertGt(fee, 13 * 1e18);
//         assertLt(fee, 14 * 1e18);
//     }

//     function testTool() public pure {
//         string memory gpuType1 = "NVIDIA GeForce RTX 4060 Ti";
//         assertEq(ToolLib.checkString(gpuType1), true, "checkString failed1");

//         string memory gpuType2 = "Gen Intel(R) Core(TM) i7-13790F";
//         assertEq(ToolLib.checkString(gpuType2), false, "checkString failed2");

//         string memory gpuType3 = "NVIDIA GeForce RTX 20 Ti";
//         assertEq(ToolLib.checkString(gpuType3), true, "checkString failed3");
//     }

//     function claimAfter(string memory machineId, address _owner, uint256 hour, bool shouldGetMore) internal {
//         uint256 balance1 = rewardToken.balanceOf(_owner);
//         passHours(hour);
//         vm.prank(_owner);
//         nftStaking.claim(machineId);
//         uint256 balance2 = rewardToken.balanceOf(_owner);
//         if (shouldGetMore) {
//             assertGt(balance2, balance1);
//         } else {
//             assertEq(balance2, balance1);
//         }
//     }
// }
