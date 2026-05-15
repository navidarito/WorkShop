@isTest
private class AccountPriorityTest {
    // This is the starting test to prove the 'Bad Trigger' fails bulk logic
    
    @isTest 
    static void testBulkTriggerFailure() {
        // 1. Setup: Create 200 Accounts (Hardcoded setup for the 'Red' phase)
        List<Account> accs = new List<Account>();
        for(Integer i=0; i<200; i++) {
            accs.add(new Account(Name = 'Bulk Test ' + i));
        }
        insert accs;

        // 2. Setup: Create 200 Opportunities
        List<Opportunity> opps = new List<Opportunity>();
        for(Account a : accs) {
            opps.add(new Opportunity(
                Name = 'Opp', 
                StageName = 'Prospecting', 
                CloseDate = Date.today(), 
                Amount = 10000, 
                AccountId = a.Id
            ));
        }
        insert opps;

        // 3. Action & Verification
        Test.startTest();
        try {
            // This update triggers the Bad Trigger's SOQL-in-a-loop
            update accs; 
            System.assert(false, 'Should have failed with LimitException');
        } catch (System.LimitException e) {
            // We verify that the bad code actually hit the limit
            Assert.isTrue(e.getMessage().contains('Too many SOQL queries: 101'), 'Expected SOQL limit error');
        }
        Test.stopTest();
    }
}