@IsTest
private class ClaimProcessorTest {

    private class MockSelector implements ISelector {
        public List<Claim__c> getPendingClaims() {
            return new List<Claim__c>{
                new Claim__c(Id = 'a00000000000001EAA', Country_Code__c = 'US', Amount__c = 100, Status__c = 'Pending', State_Code__c = 'NY'),
                new Claim__c(Id = 'a00000000000002EAA', Country_Code__c = 'MX', Amount__c = 200, Status__c = 'Pending', Tax_ID__c = 'MX-123'),
                new Claim__c(Id = 'a00000000000003EAA', Country_Code__c = 'UK', Amount__c = 300, Status__c = 'Pending')
            };
        }
    }

    private class MockNotifier implements INotifier {
        public void notify(List<Claim__c> claims) {}
    }

    @IsTest
    static void should_ProcessAllClaimTypes_Correctly() {
        ISelector selector = new MockSelector();
        INotifier notifier = new MockNotifier();
        Map<String, IClaimStrategy> strategies = new Map<String, IClaimStrategy>{
            'US' => new USClaimStrategy(),
            'MX' => new MexicoClaimStrategy()
        };

        ClaimProcessor proc = new ClaimProcessor(selector, notifier, strategies);

        Test.startTest();
        List<Claim__c> results = proc.processAll();
        Test.stopTest();

        for(Claim__c c : results) {
            if(c.Country_Code__c == 'US') {
                System.assertEquals('Approved', c.Status__c);
                System.assertEquals(7.00, c.Tax_Amount__c);
                System.assertEquals(107.00, c.Total_With_Tax__c);
            } else if(c.Country_Code__c == 'MX') {
                System.assertEquals('Approved', c.Status__c);
                System.assertEquals(32.00, c.Tax_Amount__c);
                System.assertEquals(232.00, c.Total_With_Tax__c);
            } else if(c.Country_Code__c == 'UK') {
                System.assertEquals('Rejected', c.Status__c);
                System.assert(c.Error_Log__c.contains('No strategy found'));
            }
        }
    }
}