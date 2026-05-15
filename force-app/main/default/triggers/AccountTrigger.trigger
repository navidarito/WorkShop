trigger AccountTrigger on Account (before update) {
    // FIXED: Use 'before update' to modify fields on the record 
    // without needing an extra DML 'update' statement.
    if (Trigger.isUpdate && Trigger.isBefore) {
        // Delegate all logic to the service
        AccountPriorityService.calculatePriority(Trigger.new);
    }
}