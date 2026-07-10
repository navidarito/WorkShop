@isTest
private class ServiceRequestBatchProcessorTest {

    @isTest
    static void shouldSetHighPriorityWhenRegionIsNorthAndScoreIsStrictlyGreaterThan80() {
        // Arrange
        List<Service_Request__c> testData = new List<Service_Request__c>{
            TestDataFactory.createServiceRequest('New', 'North', 81, 'Low'), // Pass threshold
            TestDataFactory.createServiceRequest('New', 'North', 80, 'Low')  // Exact boundary edge case (Should be Medium)
        };
        insert testData;

        // Act
        Test.startTest();
        Database.executeBatch(new ServiceRequestBatchProcessor(), 200);
        Test.stopTest();

        // Assert
        List<Service_Request__c> results = [SELECT Score__c, Priority__c FROM Service_Request__c WHERE Region__c = 'North' ORDER BY Score__c DESC];
        System.assertEquals('High', results[0].Priority__c, 'Score of 81 should update to High.');
        System.assertEquals('Medium', results[1].Priority__c, 'Score of exactly 80 should only be Medium.');
    }

    @isTest
    static void shouldSetMediumPriorityWhenScoreIsStrictlyGreaterThan50AndRegionIsNotNorth() {
        // Arrange
        List<Service_Request__c> testData = new List<Service_Request__c>{
            TestDataFactory.createServiceRequest('In Progress', 'South', 51, 'Low'), // Pass threshold
            TestDataFactory.createServiceRequest('In Progress', 'South', 50, 'High') // Exact boundary edge case (Should be Low)
        };
        insert testData;

        // Act
        Test.startTest();
        Database.executeBatch(new ServiceRequestBatchProcessor(), 200);
        Test.stopTest();

        // Assert
        List<Service_Request__c> results = [SELECT Score__c, Priority__c FROM Service_Request__c WHERE Region__c = 'South' ORDER BY Score__c DESC];
        System.assertEquals('Medium', results[0].Priority__c, 'Score of 51 should update to Medium.');
        System.assertEquals('Low', results[1].Priority__c, 'Score of exactly 50 should drop down to Low.');
    }

    @isTest
    static void shouldNotQueryOrMutateRecordsWhenStatusIsClosed() {
        // Arrange
        Service_Request__c closedRequest = TestDataFactory.createServiceRequest('Closed', 'North', 95, 'Low');
        insert closedRequest;

        // Act
        Test.startTest();
        Database.executeBatch(new ServiceRequestBatchProcessor(), 200);
        Test.stopTest();

        // Assert
        Service_Request__c result = [SELECT Priority__c FROM Service_Request__c WHERE Id = :closedRequest.Id];
        System.assertEquals('Low', result.Priority__c, 'Closed records must remain untouched by the batch engine query framework.');
    }

    @isTest
    static void shouldSetLowPriorityWhenScoreIsNull() {
        // Arrange - Edge case handling missing numeric scores safely
        Service_Request__c nullScoreRequest = TestDataFactory.createServiceRequest('New', 'North', null, 'High');
        insert nullScoreRequest;

        // Act
        Test.startTest();
        Database.executeBatch(new ServiceRequestBatchProcessor(), 200);
        Test.stopTest();

        // Assert
        Service_Request__c result = [SELECT Priority__c FROM Service_Request__c WHERE Id = :nullScoreRequest.Id];
        System.assertEquals('Low', result.Priority__c, 'Null fields should fall back safely to Low priority instead of crashing.');
    }

    @isTest
    static void shouldProcessSuccessfullyWhenRunningBulkDataVolume() {
        // Arrange - Bulk safety threshold check matching our exact batch size chunk limit of 200
        List<Service_Request__c> bulkRequests = TestDataFactory.createBulkServiceRequests(200, 'New', 'West', 65, 'Low');
        insert bulkRequests;

        // Act
        Test.startTest();
        Database.executeBatch(new ServiceRequestBatchProcessor(), 200);
        Test.stopTest(); // Flushes the queue completely. Because 200 <= 200, it is exactly 1 chunk execution.

        // Assert
        List<Service_Request__c> results = [SELECT Priority__c FROM Service_Request__c WHERE Region__c = 'West'];
        System.assertEquals(200, results.size(), 'All test records should remain in the database.');
        for(Service_Request__c req : results) {
            System.assertEquals('Medium', req.Priority__c, 'Every record within the bulk transaction chunk should match mutation patterns.');
        }
    }
}