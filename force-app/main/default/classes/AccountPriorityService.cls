public class AccountPriorityService {
    
    public static void calculatePriority(List<Account> accounts) {
        Set<Id> accIds = new Map<Id, Account>(accounts).keySet();
        
        Map<Id, Decimal> totalsMap = new Map<Id, Decimal>();
        for(AggregateResult ar : [SELECT AccountId, SUM(Amount) total FROM Opportunity 
                                  WHERE AccountId IN :accIds GROUP BY AccountId]) {
            totalsMap.put((Id)ar.get('AccountId'), (Decimal)ar.get('total'));
        }

        for(Account acc : accounts) {

            Decimal totalAmount = totalsMap.get(acc.Id);
            if (totalAmount == null) totalAmount = 0;
            
            try {

                Integer creditRating = 0;
                if(Limits.getCallouts() < Limits.getLimitCallouts()) {
                    creditRating = getCreditRating(acc.Id);
                }
                
                acc.Priority_Score__c = (totalAmount / 10000) + creditRating;
            } catch (Exception e) {
                acc.addError('Critical failure: ' + e.getMessage());
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