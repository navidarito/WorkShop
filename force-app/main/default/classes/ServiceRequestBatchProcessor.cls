public class ServiceRequestBatchProcessor implements Database.Batchable<sObject>, Database.Stateful {
    
    // Track execution health across batches
    public Integer totalRecordsProcessed = 0;
    public Integer totalRecordsUpdated = 0;
    public Integer totalFailures = 0;

    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Use a selective, positive query state instead of '!='
        // Ensure Status__c is indexed or part of a composite index
        Set<String> openStatuses = new Set<String>{'New', 'In Progress', 'On Hold', 'Escalated'};
        
        return Database.getQueryLocator([
            SELECT Id, Status__c, Priority__c, Region__c, Score__c
            FROM Service_Request__c
            WHERE Status__c IN :openStatuses
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Service_Request__c> scope) {
        List<Service_Request__c> requestsToUpdate = new List<Service_Request__c>();
        totalRecordsProcessed += scope.size();

        for (Service_Request__c req : scope) {
            String targetPriority = 'Low';
            
            // Determine the priority based on criteria
            if (req.Region__c == 'North' && req.Score__c > 80) {
                targetPriority = 'High';
            } else if (req.Score__c > 50) {
                targetPriority = 'Medium';
            }

            // PERFORMANCE OPTIMIZATION: Only add to update list if value actually changes
            if (req.Priority__c != targetPriority) {
                req.Priority__c = targetPriority;
                requestsToUpdate.add(req);
            }
        }

        if (!requestsToUpdate.isEmpty()) {
            // Allow partial success so one bad record doesn't roll back the whole batch
            Database.SaveResult[] results = Database.update(requestsToUpdate, false);
            
            for (Database.SaveResult sr : results) {
                if (sr.isSuccess()) {
                    totalRecordsUpdated++;
                } else {
                    totalFailures++;
                    for (Database.Error err : sr.getErrors()) {
                        System.debug(LoggingLevel.ERROR, 'Error updating record ' + sr.getId() + ': ' + err.getMessage());
                    }
                }
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        // Monitoring and Alerting Strategy
        System.debug(LoggingLevel.INFO, '=== Batch Process Completed ===');
        System.debug(LoggingLevel.INFO, 'Total Processed: ' + totalRecordsProcessed);
        System.debug(LoggingLevel.INFO, 'Total Updated: ' + totalRecordsUpdated);
        System.debug(LoggingLevel.INFO, 'Total Failures: ' + totalFailures);
        
        // Optional: Send an email alert or log to a custom Exception_Log__c object if totalFailures > 0
    }
}