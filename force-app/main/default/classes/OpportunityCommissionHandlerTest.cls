@isTest
private class OpportunityCommissionHandlerTest {

    @isTest
    static void shouldBulkCreateCommissionTasksWithPremiumRateWhenHotPartnerAccountsAreClosedWon() {
        // Arrange
        Account acc = OpportunityTestDataFactory.createPartnerAccount('Premium Partner Account', 'Hot');
        List<Opportunity> oppList = OpportunityTestDataFactory.createBaseOpportunities(acc.Id, 200);
        insert oppList;
        
        // Act
        for (Opportunity opp : oppList) {
            opp.StageName = 'Closed Won';
        }
        
        Test.startTest();
        update oppList;
        Test.stopTest();
        
        // Assert
        List<Task> createdTasks = [SELECT Id, Description FROM Task WHERE WhatId IN :oppList];
        System.assertEquals(200, createdTasks.size(), 'Every closed won opportunity must generate a commission task.');
        System.assert(createdTasks[0].Description.contains('Calculated Commission: $100.0'), 'The commission description calculation is wrong.');
    }
    
    @isTest
    static void shouldSkipTaskGenerationAndNotFailWhenOpportunityIsMissingAccountOrAmount() {
        // Arrange (Edge Case: Orphaned Opportunity and Empty Financials)
        List<Opportunity> oppList = OpportunityTestDataFactory.createBaseOpportunities(null, 1);
        Opportunity brokenOpp = oppList[0];
        brokenOpp.Name = 'Broken Opp';
        brokenOpp.Amount = null; // No money amount
        insert brokenOpp;
        
        // Act
        brokenOpp.StageName = 'Closed Won';
        
        Test.startTest();
        update brokenOpp;
        Test.stopTest();
        
        // Assert
        List<Task> createdTasks = [SELECT Id FROM Task WHERE WhatId = :brokenOpp.Id];
        System.assertEquals(0, createdTasks.size(), 'An opportunity without an account or amount should skip task generation.');
    }

    @isTest
    static void shouldIgnoreTriggerWhenOpportunityIsUpdatedButStageDoesNotChange() {
        // Arrange (Edge Case: Trigger Re-entry / Mass Updates to Existing Closed Won)
        Account acc = OpportunityTestDataFactory.createPartnerAccount('Standard Partner Account', 'Warm');
        List<Opportunity> oppList = OpportunityTestDataFactory.createBaseOpportunities(acc.Id, 1);
        oppList[0].StageName = 'Closed Won'; // Set to Closed Won on initial creation
        insert oppList;
        
        // Clear tasks created during the initial insert phase to establish a clean baseline
        delete [SELECT Id FROM Task WHERE WhatId = :oppList[0].Id];
        
        // Act 
        // Update a completely different field while keeping stage as 'Closed Won'
        oppList[0].Description = 'Updating a random field on an already closed record.';
        
        Test.startTest();
        update oppList;
        Test.stopTest();
        
        // Assert
        List<Task> createdTasks = [SELECT Id FROM Task WHERE WhatId = :oppList[0].Id];
        System.assertEquals(0, createdTasks.size(), 'Should not create duplicate tasks if the stage did not actively transition to Closed Won.');
    }

    @isTest
    static void shouldApplyStandardRateWhenAccountRatingIsNull() {
        // Arrange (Edge Case: Unpopulated or null picking values on dependencies)
        Account acc = OpportunityTestDataFactory.createPartnerAccount('Null Rating Account', null);
        List<Opportunity> oppList = OpportunityTestDataFactory.createBaseOpportunities(acc.Id, 1);
        insert oppList;
        
        // Act
        oppList[0].StageName = 'Closed Won';
        
        Test.startTest();
        update oppList;
        Test.stopTest();
        
        // Assert
        List<Task> createdTasks = [SELECT Id, Description FROM Task WHERE WhatId = :oppList[0].Id];
        System.assertEquals(1, createdTasks.size());
        System.assert(createdTasks[0].Description.contains('Calculated Commission: $50.0'), 'Should fall back gracefully to the standard 5% rate if the Account Rating field is empty.');
    }
}