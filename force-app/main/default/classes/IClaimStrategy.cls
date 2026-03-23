public interface IClaimStrategy {
    void validate(Claim__c claim);
    void applyTax(Claim__c claim);
}