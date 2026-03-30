public class SpainClaimStrategy implements IClaimStrategy {
    public void validate(Claim__c claim) {
        if (claim.Amount__c == null || claim.Amount__c <= 0) {
            throw new IllegalArgumentException('Amount is required for Spain.');
        }
        
        // Validation for Spain Tax ID
        if (String.isBlank(claim.Tax_ID__c)) {
            throw new IllegalArgumentException('NIF/CIF (Tax ID) is mandatory for Spain.');
        }
    }

    public void applyTax(Claim__c claim) {
        // Spain Standard IVA is 21%
        claim.Tax_Amount__c = claim.Amount__c * 0.21;
    }

    public void calculateTotal(Claim__c claim) {
        
        Decimal amount = claim.Amount__c != null ? claim.Amount__c : 0;
        Decimal tax = claim.Tax_Amount__c != null ? claim.Tax_Amount__c : 0;
        
        claim.Total_With_Tax__c = amount + tax;
    }
}