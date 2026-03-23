public class ClaimProcessor {
    private ISelector selector;
    private INotifier notifier;

    public ClaimProcessor(ISelector selector, INotifier notifier) {
        this.selector = selector;
        this.notifier = notifier;
    }

    public List<Claim__c> processAll() {
  
        List<Claim__c> claims = selector.getPendingClaims();
        
        for (Claim__c c : claims) {
            c.Status__c = 'Approved';
        }
        
        notifier.notify(claims);
        
        return claims;
    }
}