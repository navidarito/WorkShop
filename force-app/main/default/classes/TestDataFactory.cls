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

    /**
     * Creates `count` bare Accounts, optionally inserting them. Restores the
     * factory method AccountPriorityTest depends on but that was missing,
     * which left that test class uncompilable.
     */
    public static List<Account> createAccounts(Integer count, Boolean doInsert) {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < count; i++) {
            accounts.add(new Account(Name = 'Test Account ' + i));
        }
        if (doInsert) {
            insert accounts;
        }
        return accounts;
    }

    /**
     * Inserts one Opportunity per Account with the given Amount, so callers can
     * control each account's Opportunity total precisely.
     */
    public static List<Opportunity> createOppsForAccounts(List<Account> accounts, Decimal amountPerOpp) {
        List<Opportunity> opps = new List<Opportunity>();
        for (Account acc : accounts) {
            opps.add(new Opportunity(
                Name = 'Test Opp for ' + acc.Id,
                AccountId = acc.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30),
                Amount = amountPerOpp
            ));
        }
        insert opps;
        return opps;
    }
}