### review the fault machine report
 - The following action is required by admins which set by setAdminsToApproveMachineFaultReporting(..)
1. check pendingSlashMachineIds on rent contract to get the machine id which reported.
2. call approveMachineFaultReporting(..) or rejectMachineFaultReporting(..) on rent contract to approve or reject the report.
3. if 2/3 admins approve the report, approve the machine by calling approveMachineFaultReporting(..) on rent contract. the slash will be executed, the machine  will be remove from staking contract  and  if the reserve amount or unclaimed reward more than 10000, the reserve amount will be slashed to reporter. 