public class USClaimStrategy implements IClaimStrategy {
    public void validate(Claim__c claim) {
        if (claim.Amount__c == null || claim.Amount__c <= 0) {
            throw new IllegalArgumentException('Amount is required for US.');
        }
    }

    public void applyTax(Claim__c claim) {
        claim.Tax_Amount__c = claim.Amount__c * 0.07;
    }

    public void calculateTotal(Claim__c claim) {

        Decimal amount = claim.Amount__c != null ? claim.Amount__c : 0;
        Decimal tax = claim.Tax_Amount__c != null ? claim.Tax_Amount__c : 0;
        
        claim.Total_With_Tax__c = amount + tax;
    }
}