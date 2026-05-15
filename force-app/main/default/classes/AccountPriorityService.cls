public class AccountPriorityService {
    
    public static void calculatePriority(List<Account> accounts) {
        Set<Id> accIds = new Map<Id, Account>(accounts).keySet();
        
        // Bulkified Query: One query for all accounts
        Map<Id, Decimal> totalsMap = new Map<Id, Decimal>();
        for(AggregateResult ar : [SELECT AccountId, SUM(Amount) total FROM Opportunity 
                                  WHERE AccountId IN :accIds GROUP BY AccountId]) {
            totalsMap.put((Id)ar.get('AccountId'), (Decimal)ar.get('total'));
        }

        for(Account acc : accounts) {
            Decimal totalAmount = totalsMap.containsKey(acc.Id) ? totalsMap.get(acc.Id) : 0;
            
            try {
                // Mockable Callout logic
                Integer creditRating = getCreditRating(acc.Id);
                acc.Priority_Score__c = (totalAmount / 10000) + creditRating;
            } catch (Exception e) {
                // Scenario: Exceptions/Unexpected
                acc.addError('Critical failure in Priority Calculation: ' + e.getMessage());
            }
        }
    }

    private static Integer getCreditRating(Id accId) {
        Http h = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.example.com/credit/' + accId);
        req.setMethod('GET');
        HttpResponse res = h.send(req);
        
        if(res.getStatusCode() != 200) throw new CalloutException('API Error');
        return Integer.valueOf(res.getBody());
    }
}