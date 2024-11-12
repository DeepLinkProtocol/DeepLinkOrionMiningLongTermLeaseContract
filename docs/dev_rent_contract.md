### Contract:
    Rent: 0x40e17665515108f72304ef3f0a20336a67575e3b
      -- ABI: https://blockscout-testnet.dbcscan.io/address/0x6be8bFd70b344B0FE3F4CA3459B6b6B83607d7f9?tab=contract

### Network : DeepBrainChain Testnet

#### Rent Contract Methods:

* getDLCMachineRentFee(string memory machineId, uint256 rentBlockNumbers, uint256 rentGpuNumbers) returns (uint256) - Get rent fee for given machine id, rent block numbers and rent gpu numbers.

* rentMachine(string  machineId, uint256 rentBlockNumbers, uint8 gpuCount, uint256 rentFee) - Rent machine with given rent fee and rent block numbers and gpu count.

* endRentMachine(uint256 rentId) - End rent machine with given rent id. only machine owner can call this function

* setAdminsToApproveMachineFaultReporting(address[] admins) - set admins to approve or reject machine fault reporting. only contract owner can call this function.

* reportMachineFault(uint256 rentId, uint256 reserveAmount) - report machine fault with given rent id and reserve amount.

* approveMachineFaultReporting(string machineId) - approve machine for reporting faults. only admin can call this function.

* rejectMachineFaultReporting(string machineId) - reject machine for reporting faults. only admin can call this function.