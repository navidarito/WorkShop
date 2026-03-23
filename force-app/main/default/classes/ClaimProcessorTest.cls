@IsTest
private class ClaimProcessorTest {

    private class MockSelector implements ISelector {
        public List<Claim__c> getPendingClaims() {
            return new List<Claim__c>{
                new Claim__c(Id = 'a00000000000001EAA', Country_Code__c = 'US', Status__c = 'Pending'),
                new Claim__c(Id = 'a00000000000002EAA', Country_Code__c = 'ES', Status__c = 'Pending')
            };
        }
    }

    private class MockNotifier implements INotifier {
        public void notify(List<Claim__c> claims) {}
    }

    private class SuccessStrategy implements IClaimStrategy {
        public void validate(Claim__c claim) {}
        public void applyTax(Claim__c claim) {
            claim.Tax_Amount__c = 100.00;
        }
    }

    private class FailingStrategy implements IClaimStrategy {
        public void validate(Claim__c claim) {
            throw new IllegalArgumentException('Missing Required Documents');
        }
        public void applyTax(Claim__c claim) {}
    }

    @IsTest
    static void should_ApproveClaims_WhenStrategySucceeds() {
        ISelector selector = new MockSelector();
        INotifier notifier = new MockNotifier();
        Map<String, IClaimStrategy> strategies = new Map<String, IClaimStrategy>{
            'US' => new SuccessStrategy()
        };

        ClaimProcessor proc = new ClaimProcessor(selector, notifier, strategies);

        List<Claim__c> results = proc.processAll();

        System.assertEquals('Approved', results[0].Status__c);
        System.assertEquals(100.00, results[0].Tax_Amount__c);
    }

    @IsTest
    static void should_RejectClaims_WhenValidationFails() {
        ISelector selector = new MockSelector();
        INotifier notifier = new MockNotifier();
        Map<String, IClaimStrategy> strategies = new Map<String, IClaimStrategy>{
            'ES' => new FailingStrategy()
        };

        ClaimProcessor proc = new ClaimProcessor(selector, notifier, strategies);

        List<Claim__c> results = proc.processAll();

        for(Claim__c c : results) {
            if(c.Country_Code__c == 'ES') {
                System.assertEquals('Rejected', c.Status__c);
                System.assertEquals('Missing Required Documents', c.Error_Log__c);
            }
        }
    }
}