deeplink长租竞赛质押合约接口文档(dbcscan)
================

## 描述
deeplink长租竞赛质押合约是用于管理 NFT 质押的智能合约。它提供了多种功能，包括质押、解质押、领取奖励等。

## 合约地址(主网)
    质押合约：0x3c059dbe0f42d65acd763c3c3da8b5a1b12bb74f
    nft: 0xFDB11c63b82828774D6A9E893f85D1998E6B36BF
    dlc token: 0x6f8F70C74FE7d7a61C8EAC0f35A4Ba39a51E1BEe

## 函数接口
### `stake(string calldata machineId, calldata nftTokenIds,uint256[] calldata nftTokenIdBalances, uint256 rentId, address rewardReceiver) public nonReentrant`
- 描述：质押nft
- 参数：
    - `machineId`: 机器 ID
    - `nftTokenIds`: NFT Token ID 数组
    - `nftTokenIdBalances`: NFT Token ID 数量数组
    - `rentId`: 在dbc链上的租用id
    - `rewardReceiver`: 奖励接收者地址
- 返回值：无
- 事件：
    - `staked`: 质押NFT成功事件
  
### `addDLCToStake(string calldata machineId, uint256 amount) public nonReentrant`
- 描述：质押dlc
- 参数：
  - `machineId`: 机器 ID
  - `amount`: 质押金额 可以为0 单位为wei
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
- 描述：领取奖励 只能被质押人调用
- 参数：
  - `machineId`: 机器 ID
- 返回值：无
- 事件：
  - `claimed`: 领取奖励成功事件

### `function addNFTsToStake(string calldata machineId,uint256[] calldata nftTokenIds,uint256[] calldata nftTokenIdBalances) external`
- 描述：追加nft质押
- 参数：
  - `machineId`: 机器 ID
  - `nftTokenIds`: NFT Token ID 数组
  - `nftTokenIdBalances`: NFT Token ID 数量数组
- 返回值：无

### `function addStakeHours(address holder, string[] calldata machineIds, uint256[] calldata additionHoursList) external`
- 描述：续租
- 参数：
  - `holder`: 质押人地址
  - `machineIds`: 要续租的机器id列表
  - `additionHoursList`: 续租时间列表 单位为小时
- 返回值：无


## 全局变量
- 'dailyRewardAmount' uint256: 每日总的奖励数量

- 'totalStakingGpuCount' uint256 : 当前处于质押状态GPU的总数量
