public class ClaimService {
    /**
     * Entry point to process all pending claims across all countries.
     * This method handles the Dependency Injection (Wiring) and the DML.
     */
    public static void processPendingClaims() {
        // 1. Define the strategy registry
        // This makes it easy to add new countries in the future
        Map<String, IClaimStrategy> strategyMap = new Map<String, IClaimStrategy>{
            'US' => new USClaimStrategy(),
            'ES' => new SpainClaimStrategy(),
            'MX' => new MexicoClaimStrategy()
        };

        // 2. Initialize the Processor with concrete implementations
        // Note: We use the real Selector and Notifier here
        ClaimProcessor processor = new ClaimProcessor(
            new ClaimSelector(), 
            new EmailNotifier(), 
            strategyMap
        );

        // 3. Execute the business logic
        List<Claim__c> processedClaims = processor.processAll();

        // 4. Persistence Layer (Bulk DML)
        // We perform the update here to keep the Processor side-effect free (pure logic)
        if (!processedClaims.isEmpty()) {
            update processedClaims;
        }
    }
}