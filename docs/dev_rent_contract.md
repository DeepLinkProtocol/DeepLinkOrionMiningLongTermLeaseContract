### Contract:
    Rent: 0xb7b29861e91aaf3677861cf2c4f8f7baefa73293

### Network : DeepBrainChain Testnet

#### Rent Contract Methods:

* getDLCMachineRentFee(string memory machineId, uint256 rentBlockNumbers, uint256 rentGpuNumbers) returns (uint256) - Get rent fee for given machine id, rent block numbers and rent gpu numbers.

* rentMachine(string  machineId, uint256 rentBlockNumbers, uint8 gpuCount, uint256 rentFee) - Rent machine with given rent fee and rent block numbers and gpu count.

* endRentMachine(uint256 rentId) - End rent machine with given rent id. only machine owner can call this function

* setAdminsToApproveMachineFaultReporting(address[] admins) - set admins to approve or reject machine fault reporting. only contract owner can call this function.

* reportMachineFault(uint256 rentId, uint256 reserveAmount) - report machine fault with given rent id and reserve amount.

* approveMachineFaultReporting(string machineId) - approve machine for reporting faults. only admin can call this function.

* rejectMachineFaultReporting(string machineId) - reject machine for reporting faults. only admin can call this function.