public class ClaimSelector implements ISelector {
    public List<Claim__c> getPendingClaims() {
        return [SELECT Id, 
                       Amount__c, 
                       Country_Code__c, 
                       Status__c, 
                       Tax_Amount__c, 
                       Error_Log__c, 
                       State_Code__c,  
                       Tax_ID__c,
                       Total_With_Tax__c
                FROM Claim__c 
                WHERE Status__c = 'Pending'];
    }
}