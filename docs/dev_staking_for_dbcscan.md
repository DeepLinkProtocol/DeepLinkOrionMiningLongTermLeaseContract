deeplink长租竞赛质押合约接口文档(dbcscan)
================

## 描述
deeplink长租竞赛质押合约是用于管理 NFT 质押的智能合约。它提供了多种功能，包括质押、解质押、领取奖励等。

## 合约地址(测试网)
    质押合约：0x23ba922d2c435ea65aceb6d56feec7a7c29948b8
    nft: 0x905dE58579886C5afe9B6406CFDE82bd6a1087C1
    dlc token: 0xC8b47112D5413c6d06D4BB7573fD903908246614

## 函数接口
### `stake(string calldata machineId, calldata nftTokenIds,uint256[] calldata nftTokenIdBalances, uint256 rentId) public nonReentrant`
- 描述：质押nft
- 参数：
    - `machineId`: 机器 ID
    - `nftTokenIds`: NFT Token ID 数组
    - `nftTokenIdBalances`: NFT Token ID 数量数组
    - `rentId`: 在dbc链上的租用id
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

### `getMachineInfoForDBCScan(string calldata machineId) external view returns (MachineInfoForDBCScan memory)`
- 描述：获取机器信息
- 参数：
  - `machineId`: 机器 ID
- 返回值：`MachineInfoForDBCScan`

```solidity
 struct MachineInfoForDBCScan {
        bool isStaking;  // 是否在质押
        string gpuType;  // gpu类型
        uint8  gpuCount; // gpu数量
        uint256 mem;     // 内存大小 G
        string projectName;  // 项目名字
        uint256 totalRewardAmount;    // 总奖励数量
        uint256 claimedRewardAmount;  // 已领取奖励数量
        uint256 lockedRewardAmount;    // 锁仓奖励数量
    }
```



## 全局变量
- 'dailyRewardAmount' uint256: 每日总的奖励数量

- 'totalStakingGpuCount' uint256 : 当前处于质押状态GPU的总数量

- 'holder2MachineIds' mapping(address => string[]): 质押人地址到机器ID的映射