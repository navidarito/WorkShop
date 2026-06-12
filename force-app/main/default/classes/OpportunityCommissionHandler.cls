public class OpportunityCommissionHandler {
    
    public static void handleClosedWonOpportunities(List<Opportunity> newOpps, Map<Id, Opportunity> oldOpps) {
        List<Task> tasksToInsert = new List<Task>();
        Set<Id> accountIds = new Set<Id>();
        List<Opportunity> validOpps = new List<Opportunity>();
        
        // Step 1: Filter opportunities and safely collect Account IDs
        for (Opportunity opp : newOpps) {
            // Safely grab the historical state of the record if it exists
            Opportunity oldOpp = (oldOpps != null && oldOpps.containsKey(opp.Id)) ? oldOpps.get(opp.Id) : null;
            
            // Edge Case Protection: Verify the stage ACTUALLY changed to Closed Won
            // This prevents duplicate tasks if a user edits a record that is already Closed Won
            Boolean isClosedWonTransition = (opp.StageName == 'Closed Won' && (oldOpp == null || oldOpp.StageName != 'Closed Won'));
            
            // Edge Case Protection: Skip records missing required calculation data (Account or Amount)
            if (isClosedWonTransition && opp.AccountId != null && opp.Amount != null) {
                accountIds.add(opp.AccountId);
                validOpps.add(opp);
            }
        }
        
        // Guard Clause: If no records match criteria, exit immediately to save CPU time
        if (validOpps.isEmpty()) {
            return;
        }
        
        // Step 2: Single bulk SOQL query outside the loop
        Map<Id, Account> accountMap = new Map<Id, Account>([
            SELECT Id, Rating 
            FROM Account 
            WHERE Id IN :accountIds
        ]);
        
        // Step 3: Loop through filtered records and construct standard Tasks
        for (Opportunity opp : validOpps) {
            Account parentAcc = accountMap.get(opp.AccountId);
            
            // Default 5% commission rate
            Decimal rate = 0.05; 
            
            // Edge Case Protection: Handle missing or unpopulated Account Map values gracefully
            if (parentAcc != null && parentAcc.Rating == 'Hot') {
                rate = 0.10; // Premium 10% rate
            }
            
            Decimal commissionAmount = opp.Amount * rate;
            
            Task commTask = new Task(
                Subject = 'Commission Processing Required',
                WhatId = opp.Id,
                OwnerId = opp.OwnerId,
                Status = 'Not Started',
                Priority = 'High',
                Description = 'Calculated Commission: $' + commissionAmount + ' based on a ' + (rate * 100) + '% rate.'
            );
            tasksToInsert.add(commTask);
        }
        
        // Step 4: Single bulk DML insert outside the loop
        if (!tasksToInsert.isEmpty()) {
            insert tasksToInsert;
        }
    }
}