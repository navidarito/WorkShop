// Everything is in the trigger. No way to test without DML. 
// No way to mock the callout.
trigger AccountTrigger on Account (after update) {
    // TRIGGER SMELL: Logic is inside the trigger instead of a Service class.
    for (Account acc : Trigger.new) {
        
        // BAD PRACTICE: SOQL inside a loop. 
        // This will hit the 100-query limit if you update > 100 Accounts.
        List<Opportunity> opps = [SELECT Amount FROM Opportunity WHERE AccountId = :acc.Id];
        
        Decimal totalAmount = 0;
        for(Opportunity o : opps) {
            if(o.Amount != null) {
                totalAmount += o.Amount;
            }
        }

        // BAD PRACTICE: Hardcoded business logic that is difficult to modify.
        Decimal score = (totalAmount / 10000);
        
        // BAD PRACTICE: Directly updating the record in an 'after' trigger 
        // without a check, which could cause an infinite recursion loop.
        Account recordToUpdate = new Account(Id = acc.Id, Priority_Score__c = score);
        
        // BAD PRACTICE: DML inside a loop. 
        // This will hit the 150-DML limit in bulk scenarios.
        update recordToUpdate; 
    }
}