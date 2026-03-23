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
            // Find the strategy based on the country code
            IClaimStrategy strategy = strategies.get(c.Country_Code__c);
            
            if (strategy != null) {
                try {
                    strategy.validate(c);
                    strategy.applyTax(c);
                    c.Status__c = 'Approved';
                } catch (Exception e) {
                    c.Status__c = 'Rejected';
                    c.Error_Log__c = e.getMessage();
                }
            }
        }
        
        notifier.notify(claims);
        return claims;
    }
}