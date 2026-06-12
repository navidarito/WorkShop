public class OpportunityCommissionHandler {
    
    // This method is called from an Opportunity trigger after update
    public static void handleClosedWonOpportunities(List<Opportunity> newOpps, Map<Id, Opportunity> oldOpps) {
        
        for (Opportunity opp : newOpps) {
            // ANTI-PATTERN 1: Accessing old map values inside a loop without checking if the ID exists
            Opportunity oldOpp = oldOpps.get(opp.Id);
            
            // Check if it just changed to Closed Won
            if (opp.StageName == 'Closed Won' && oldOpp.StageName != 'Closed Won') {
                
                // ANTI-PATTERN 2: SOQL Query inside a FOR Loop! 
                // This will throw a "System.LimitException: Too many SOQL queries: 101" if more than 100 records are updated.
                Account acc = [SELECT Id, Rating FROM Account WHERE Id = :opp.AccountId];
                
                // ANTI-PATTERN 3: Lack of Null Pointer Exception (NPE) protection
                // If an opportunity doesn't have an Account, the query above fails, or 'acc' becomes null, crashing the transaction.
                Decimal rate = 0.05; // Default 5%
                if (acc.Rating == 'Hot') {
                    rate = 0.10; // 10% for Hot accounts
                }
                
                // Create a standard Task record
                Task commTask = new Task();
                commTask.Subject = 'Commission Processing Required';
                commTask.WhatId = opp.Id;
                commTask.OwnerId = opp.OwnerId;
                commTask.Status = 'Not Started';
                commTask.Priority = 'High';
                commTask.Description = 'Calculated Commission: $' + (opp.Amount * rate);
                
                // ANTI-PATTERN 4: DML statement (insert) inside a FOR Loop!
                // This will throw a "System.LimitException: Too many DML statements: 151" if more than 150 records are updated.
                insert commTask;
            }
        }
    }
}