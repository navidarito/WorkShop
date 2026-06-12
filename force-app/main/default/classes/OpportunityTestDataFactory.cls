@isTest
public class OpportunityTestDataFactory {
    
    // Explicit domain-specific naming
    public static Account createPartnerAccount(String name, String rating) {
        Account acc = new Account(
            Name = name,
            Rating = rating
        );
        insert acc;
        return acc;
    }
    
    // Explicit domain-specific naming
    public static List<Opportunity> createBaseOpportunities(Id accountId, Integer count) {
        List<Opportunity> oppList = new List<Opportunity>();
        for (Integer i = 0; i < count; i++) {
            oppList.add(new Opportunity(
                Name = 'Test Opp ' + i,
                StageName = 'Prospecting',
                CloseDate = System.today().addDays(30),
                Amount = 1000,
                AccountId = accountId
            ));
        }
        return oppList;
    }
}