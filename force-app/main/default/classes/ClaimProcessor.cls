public class ClaimProcessor {
    private ISelector selector;
    private INotifier notifier;
    private Map<String, IClaimStrategy> strategies;

    public ClaimProcessor(ISelector selector, INotifier notifier, Map<String, IClaimStrategy> strategies) {
        this.selector = selector;
        this.notifier = notifier;
        this.strategies = strategies;
    }

    public List<Claim__c> processAll() {
        List<Claim__c> claims = selector.getPendingClaims();

        for (Claim__c c : claims) {
            IClaimStrategy strategy = strategies.get(c.Country_Code__c);
            
            if (strategy != null) {
                try {
                    strategy.validate(c);
                    strategy.applyTax(c);
                    
                    Decimal baseAmount = (c.Amount__c != null) ? c.Amount__c : 0;
                    Decimal taxAmount = (c.Tax_Amount__c != null) ? c.Tax_Amount__c : 0;
                    c.Total_With_Tax__c = baseAmount + taxAmount;
                    
                    c.Status__c = 'Approved';
                    c.Error_Log__c = null; 
                    
                } catch (Exception e) {
                    c.Status__c = 'Rejected';
                    c.Error_Log__c = e.getMessage();
                }
            } else {
                c.Status__c = 'Rejected';
                c.Error_Log__c = 'No strategy found for country: ' + (c.Country_Code__c != null ? c.Country_Code__c : 'N/A');
            }
        }
        
        notifier.notify(claims);
        return claims;
    }
}