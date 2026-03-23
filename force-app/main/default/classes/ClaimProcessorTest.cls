@IsTest
private class ClaimProcessorTest {
    @IsTest
    static void should_ChangeStatusToApproved() {

        ISelector mockSelector = new MockSelector(); 
        ClaimProcessor proc = new ClaimProcessor(mockSelector, new MockNotifier());

        List<Claim__c> results = proc.processAll();

        System.assertEquals('Approved', results[0].Status__c);
    }
}