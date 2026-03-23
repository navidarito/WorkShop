@IsTest
private class ClaimProcessorTest {

    private class MockSelector implements ISelector {
        public List<Claim__c> getPendingClaims() {
            return new List<Claim__c>{
                new Claim__c(
                    Id = 'a00000000000001EAA', 
                    Country_Code__c = 'US', 
                    Status__c = 'Pending'
                )
            };
        }
    }

    private class MockNotifier implements INotifier {
        public void notify(List<Claim__c> claims) {}
    }

    @IsTest
    static void should_ChangeStatusToApproved() {
        ISelector mockSelector = new MockSelector(); 
        ClaimProcessor proc = new ClaimProcessor(mockSelector, new MockNotifier());

        List<Claim__c> results = proc.processAll();

        System.assertEquals('Approved', results[0].Status__c);
    }
}