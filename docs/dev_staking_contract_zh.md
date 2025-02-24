短租竞赛质押合约接口文档
================

## 合约地址(测试网)：0xa6c07a5c289a2b1b1b528baf9aa3177fd2b57d83

## 描述
短租竞赛质押合约是用于管理 NFT 质押的智能合约。它提供了多种功能，包括质押、解质押、领取奖励等。

## 函数接口
### `stake(string calldata machineId, calldata nftTokenIds,uint256[] calldata nftTokenIdBalances, uint256 rentId) public nonReentrant`
- 描述：质押nft 只能被质押人或者管理员钱包调用
= 参数：
    - `machineId`: 机器 ID
    - `nftTokenIds`: NFT Token ID 数组
    - `nftTokenIdBalances`: NFT Token ID 数量数组
    - `rentId`: 在dbc链上的租用id
- 返回值：无
- 事件：
    - `staked`: 质押NFT成功事件

### `addDLCToStake(string calldata machineId, uint256 amount) public nonReentrant`
- 描述：质押dlc 只能被管理员钱包调用
  = 参数：
  - `machineId`: 机器 ID
  - `amount`: 质押金额 可以为0
- 返回值：无
- 事件：
  - `reseveDLC`: 质押DLC成功事件


### `unStake(string calldata machineId) public nonReentrant`
- 描述：解质押 只能被质押人或者管理员钱包调用
- 参数：
    - `machineId`: 机器 ID
- 返回值：无
- 事件：
    - `unStaked`: 解质押成功事件

### `claim(string calldata machineId) public`
- 描述：领取奖励 
- 参数：
    - `machineId`: 机器 ID
- 返回值：无
- 事件：
    - `claimed`: 领取奖励成功事件

### `getRewardInfo(string memory machineId) public returns (uint256 newRewardAmount, uint256 canClaimAmount, uint256 lockedAmount, uint256 claimedAmount)`
- 描述：获取奖励信息 每次提取时 产生奖励中的10%可以立即提取 其他部分金额180天内线性解锁 每天解锁0.5%，180天后全部解锁
- 参数：
    - `machineId`: 机器 ID
- 返回值：
    - `newRewardAmount`: 上次提取时间至当前时间点所新产生的奖励数量(包含立即释放部分+180天线性解锁部分)
    - `canClaimAmount`: 可领取奖励金额(包含newRewardAmount中立即释放部分+lockedAmount中当前可解锁部分)
    - `lockedAmount`: 累积的锁定奖励金额(180天线性释放中 当前不可解锁部分)
    - `claimedAmount`: 已领取奖励金额