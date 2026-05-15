@isTest
public class TestDataFactory {
    public static List<Account> createAccounts(Integer count, Boolean doInsert) {
        List<Account> accs = new List<Account>();
        for(Integer i=0; i<count; i++) {
            accs.add(new Account(Name = 'Test Account ' + i));
        }
        if(doInsert) insert accs;
        return accs;
    }

    public static void createOppsForAccounts(List<Account> accs, Decimal amount) {
        List<Opportunity> opps = new List<Opportunity>();
        for(Account a : accs) {
            opps.add(new Opportunity(
                Name = 'Opp ' + a.Name,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(10),
                Amount = amount,
                AccountId = a.Id
            ));
        }
        insert opps;
    }
}