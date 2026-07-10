@isTest
public class TestDataFactory {
    
    /**
     * Creates a single Service Request with specific parameters
     */
    public static Service_Request__c createServiceRequest(String status, String region, Decimal score, String priority) {
        return new Service_Request__c(
            Status__c = status,
            Region__c = region,
            Score__c = score,
            Priority__c = priority
        );
    }

    /**
     * Bulk creates generic records for volume/scalability testing
     */
    public static List<Service_Request__c> createBulkServiceRequests(Integer count, String status, String region, Decimal score, String priority) {
        List<Service_Request__c> requests = new List<Service_Request__c>();
        for (Integer i = 0; i < count; i++) {
            requests.add(createServiceRequest(status, region, score, priority));
        }
        return requests;
    }
}