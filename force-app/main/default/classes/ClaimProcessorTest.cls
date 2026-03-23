@IsTest
private class ClaimProcessorTest {

    private class MockSelector implements ISelector {
        public List<Claim__c> getPendingClaims() {
            return new List<Claim__c>{
                new Claim__c(Id = 'a00000000000001EAA', Country_Code__c = 'US', Status__c = 'Pending')
            };
        }
    }

    private class MockNotifier implements INotifier {
        public void notify(List<Claim__c> claims) {}
    }

    // New Mock 
    private class MockStrategy implements IClaimStrategy {
        public void validate(Claim__c claim) { /* No errors */ }
        public void applyTax(Claim__c claim) { 
            claim.Tax_Amount__c = 10.0; 
        }
    }

    @IsTest
    static void should_ChangeStatusToApproved() {
        ISelector selector = new MockSelector(); 
        INotifier notifier = new MockNotifier();
        
        // Inject the strategy into the Map
        Map<String, IClaimStrategy> strategyMap = new Map<String, IClaimStrategy>{
            'US' => new MockStrategy()
        };
        
        ClaimProcessor proc = new ClaimProcessor(selector, notifier, strategyMap);

        List<Claim__c> results = proc.processAll();

        System.assertEquals('Approved', results[0].Status__c);
        System.assertEquals(10.0, results[0].Tax_Amount__c);
    }
}