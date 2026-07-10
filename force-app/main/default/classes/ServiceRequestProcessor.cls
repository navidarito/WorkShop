public class ServiceRequestProcessor {
    public static void recalculatePriorities() {
        List<Service_Request__c> requests = [
            SELECT Id, Status__c, Priority__c, Region__c, CreatedDate, Score__c
            FROM Service_Request__c
            WHERE Status__c != 'Closed'
        ];

        for (Service_Request__c req : requests) {
            if (req.Region__c == 'North' && req.Score__c > 80) {
                req.Priority__c = 'High';
            } else if (req.Score__c > 50) {
                req.Priority__c = 'Medium';
            } else {
                req.Priority__c = 'Low';
            }
        }

        update requests;
    }
}
