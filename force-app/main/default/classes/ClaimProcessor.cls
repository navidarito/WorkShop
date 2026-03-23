public class ClaimProcessor {
    private ISelector selector;
    private INotifier notifier;

    public ClaimProcessor(ISelector selector, INotifier notifier) {
        this.selector = selector;
        this.notifier = notifier;
    }

    public List<Claim__c> processAll() {
        return new List<Claim__c>();
    }
}