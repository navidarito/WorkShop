/**
 * Bulk / stress test suite for AccountPriorityService.
 *
 * CRITICAL FINDING while building this suite: AccountPriorityService.getCreditRating()
 * makes an HTTP callout, and it is invoked from AccountTrigger's `before update`
 * context. Salesforce does not allow synchronous callouts from a trigger at all
 * ("Callout from triggers are currently not supported") -- not a scale problem,
 * a total one. Every real Account update that reaches this trigger fails outright
 * today (proven by testProductionRisk_TriggerInvocationFailsOnEveryAccountUpdate
 * below). The existing AccountPriorityTest suite never caught this because it
 * calls AccountPriorityService.calculatePriority(...) directly and never performs
 * an actual `update` DML, so it never exercises the real trigger path.
 *
 * This suite keeps that same direct-call pattern for the bulk/limit/extreme tests
 * below (so they can isolate the service's OWN bulk-safety and callout-budget
 * behavior, which is real and worth verifying once the trigger wiring is fixed),
 * and adds one dedicated test that captures the trigger-callout defect itself.
 *
 * Coverage map (assignment rubric):
 *   1. Bulk of 200 records          -> testBulk_200Accounts_ExposesCalloutCeiling
 *   2. Multiple transactions/exec.  -> testTransaction1_/testTransaction2_ChunkOfHundred_AllGetRealCreditRating
 *   3. Governor-limit risk          -> testBulk_200Accounts_ExposesCalloutCeiling,
 *                                       testProductionRisk_TriggerInvocationFailsOnEveryAccountUpdate
 *   4. Resource consumption         -> testResourceConsumption_CpuAndQueryUsageStayBounded
 *   5. Extreme scenarios            -> testExtreme_* methods
 *   6. Deep assertions              -> every test checks exact Priority_Score__c / error values
 *   7. Future risks                 -> block comment at the bottom of this file
 */
@isTest
private class AccountPriorityServiceStressTest {

    private static final Integer CALLOUT_CEILING = 100; // Limits.getLimitCallouts() for sync Apex
    private static final Integer CREDIT_RATING_FROM_MOCK = 50; // CreditServiceMock(false) always returns "50"

    // ---------------------------------------------------------------
    // 3) The headline finding: the production wiring is broken, period.
    // ---------------------------------------------------------------

    @isTest
    static void testProductionRisk_TriggerInvocationFailsOnEveryAccountUpdate() {
        Account acc = TestDataFactory.createAccounts(1, true)[0];
        TestDataFactory.createOppsForAccounts(new List<Account>{ acc }, 1000);

        Test.setMock(HttpCalloutMock.class, new CreditServiceMock(false));

        Test.startTest();
        // allOrNone=false so the failure is captured as a SaveResult instead of throwing,
        // letting us assert on exactly why it failed.
        Database.SaveResult result = Database.update(acc, false);
        Test.stopTest();

        System.assert(!result.isSuccess(),
            'A single, otherwise-valid Account update must fail today: the trigger calls out, and '
            + 'Salesforce does not allow callouts from trigger context at all.');
        System.assert(result.getErrors()[0].getMessage().contains('Callout from triggers are currently not supported'),
            'The failure must be attributable to the callout-from-trigger platform restriction, '
            + 'not some unrelated validation error. Actual: ' + result.getErrors()[0].getMessage());
    }

    // ---------------------------------------------------------------
    // 1) Bulk of 200 + 3) governor-limit risk detection + 6) deep assertions
    //
    // These call AccountPriorityService.calculatePriority(...) directly, the same
    // way the existing AccountPriorityTest suite does, to isolate the service's
    // callout-budget behavior from the separate trigger-context defect above.
    // ---------------------------------------------------------------

    @isTest
    static void testBulk_200Accounts_ExposesCalloutCeiling() {
        List<Account> accounts = TestDataFactory.createAccounts(200, true);
        TestDataFactory.createOppsForAccounts(accounts, 10000); // each account: totalAmount = 10000 -> revenue term = 1

        Test.setMock(HttpCalloutMock.class, new CreditServiceMock(false));

        Test.startTest();
        AccountPriorityService.calculatePriority(accounts);
        Integer calloutsUsed = Limits.getCallouts();
        Test.stopTest();

        System.assertEquals(CALLOUT_CEILING, calloutsUsed,
            'The service should make exactly one callout per account until the 100-callout ceiling, then stop.');

        Integer gotRealCreditRating = 0;
        Integer gotZeroCreditRating = 0;
        for (Account acc : accounts) {
            if (acc.Priority_Score__c == 1 + CREDIT_RATING_FROM_MOCK) {
                gotRealCreditRating++;
            } else if (acc.Priority_Score__c == 1) {
                gotZeroCreditRating++;
            } else {
                System.assert(false, 'Unexpected Priority_Score__c: ' + acc.Priority_Score__c);
            }
        }

        // This is the finding: exactly half the batch silently gets a wrong (understated) score,
        // with no exception and no error raised anywhere.
        System.assertEquals(100, gotRealCreditRating,
            'Only the first 100 accounts (the callout budget) should receive a real credit rating.');
        System.assertEquals(100, gotZeroCreditRating,
            'The other 100 accounts silently get a credit rating of 0 -- a data-integrity risk with no error raised.');
    }

    @isTest
    static void testBulk_100Accounts_AtExactlyTheCeiling_AllSucceed() {
        // Regression guard: right at the boundary, everyone should still get a real score.
        List<Account> accounts = TestDataFactory.createAccounts(100, true);
        TestDataFactory.createOppsForAccounts(accounts, 5000); // revenue term = 0.5

        Test.setMock(HttpCalloutMock.class, new CreditServiceMock(false));

        Test.startTest();
        AccountPriorityService.calculatePriority(accounts);
        Test.stopTest();

        for (Account acc : accounts) {
            System.assertEquals(50.5, acc.Priority_Score__c,
                'At exactly 100 records every account should still get a real credit rating.');
        }
    }

    // ---------------------------------------------------------------
    // 2) Multiple transactions / executions
    //
    // Governor limits reset per test method (each is its own Apex transaction),
    // so two independent methods are the correct way to prove the mitigation
    // (chunking a big job into <=100-record runs) is repeatable across runs --
    // a single method calling the service twice would NOT get two separate
    // callout budgets, since limits only reset once, at Test.startTest.
    // ---------------------------------------------------------------

    @isTest
    static void testTransaction1_ChunkOfHundred_AllGetRealCreditRating() {
        List<Account> chunk = TestDataFactory.createAccounts(100, true);
        TestDataFactory.createOppsForAccounts(chunk, 10000);

        Test.setMock(HttpCalloutMock.class, new CreditServiceMock(false));

        Test.startTest();
        AccountPriorityService.calculatePriority(chunk);
        Test.stopTest();

        for (Account acc : chunk) {
            System.assertEquals(51, acc.Priority_Score__c, 'Every account in a fresh <=100 chunk must get a real credit rating.');
        }
    }

    @isTest
    static void testTransaction2_ChunkOfHundred_AllGetRealCreditRating() {
        List<Account> chunk = TestDataFactory.createAccounts(100, true);
        TestDataFactory.createOppsForAccounts(chunk, 10000);

        Test.setMock(HttpCalloutMock.class, new CreditServiceMock(false));

        Test.startTest();
        AccountPriorityService.calculatePriority(chunk);
        Test.stopTest();

        for (Account acc : chunk) {
            System.assertEquals(51, acc.Priority_Score__c,
                'A second, independent execution must behave identically to the first -- proving the '
                + 'chunking mitigation is repeatable across separate job runs, not a fluke of shared state.');
        }
    }

    // ---------------------------------------------------------------
    // 4) Resource consumption
    // ---------------------------------------------------------------

    @isTest
    static void testResourceConsumption_CpuAndQueryUsageStayBounded() {
        List<Account> accounts = TestDataFactory.createAccounts(200, true);
        TestDataFactory.createOppsForAccounts(accounts, 10000);

        Test.setMock(HttpCalloutMock.class, new CreditServiceMock(false));

        Test.startTest();
        AccountPriorityService.calculatePriority(accounts);

        System.assert(Limits.getCpuTime() < (Limits.getLimitCpuTime() / 2),
            'Even with 100 mocked callouts, CPU time should stay well under half the sync limit; '
            + 'used ' + Limits.getCpuTime() + 'ms of ' + Limits.getLimitCpuTime() + 'ms.');
        System.assertEquals(1, Limits.getQueries(),
            'Exactly one SOQL query should compute all 200 Opportunity sums (no per-record SOQL).');
        System.assertEquals(0, Limits.getDmlStatements(),
            'calculatePriority must only mutate fields in memory; it must never issue its own DML.');
        Test.stopTest();
    }

    // ---------------------------------------------------------------
    // 5) Extreme scenarios
    // ---------------------------------------------------------------

    @isTest
    static void testExtreme_AllCalloutsFail_EveryRecordGetsAnAttributedError() {
        List<Account> accounts = TestDataFactory.createAccounts(50, true);
        TestDataFactory.createOppsForAccounts(accounts, 1000);

        Test.setMock(HttpCalloutMock.class, new CreditServiceMock(true)); // simulate 500 on every callout

        Test.startTest();
        AccountPriorityService.calculatePriority(accounts);
        Test.stopTest();

        for (Account acc : accounts) {
            System.assert(acc.hasErrors(), 'Every record must have an attached error when its callout fails.');
            System.assertEquals(null, acc.Priority_Score__c,
                'When the callout fails, addError is called instead of setting a score; the field must stay unset.');
        }
    }

    @isTest
    static void testExtreme_NoOpportunities_ScoreIsCreditRatingOnly() {
        List<Account> accounts = TestDataFactory.createAccounts(80, true); // <=100, no Opportunities created at all

        Test.setMock(HttpCalloutMock.class, new CreditServiceMock(false));

        Test.startTest();
        AccountPriorityService.calculatePriority(accounts);
        Test.stopTest();

        for (Account acc : accounts) {
            System.assertEquals(CREDIT_RATING_FROM_MOCK, acc.Priority_Score__c,
                'With zero Opportunity revenue, the score must equal the credit rating alone (0/10000 + 50).');
        }
    }

    @isTest
    static void testExtreme_MixedRevenueAcrossABulkBatch_ExactMathPerAccount() {
        List<Account> highRevenue = TestDataFactory.createAccounts(10, true);
        List<Account> zeroRevenue = TestDataFactory.createAccounts(10, true);
        TestDataFactory.createOppsForAccounts(highRevenue, 250000); // revenue term = 25
        // zeroRevenue accounts intentionally get no Opportunities

        Test.setMock(HttpCalloutMock.class, new CreditServiceMock(false));

        List<Account> allAccounts = new List<Account>();
        allAccounts.addAll(highRevenue);
        allAccounts.addAll(zeroRevenue);

        Test.startTest();
        AccountPriorityService.calculatePriority(allAccounts);
        Test.stopTest();

        for (Account acc : highRevenue) {
            System.assertEquals(75, acc.Priority_Score__c, 'High-revenue accounts: 250000/10000 + 50 = 75.');
        }
        for (Account acc : zeroRevenue) {
            System.assertEquals(50, acc.Priority_Score__c, 'Zero-revenue accounts: 0/10000 + 50 = 50.');
        }
    }

    @isTest
    static void testExtreme_SingleRecord_BehavesLikeBulk() {
        List<Account> accounts = TestDataFactory.createAccounts(1, true);
        TestDataFactory.createOppsForAccounts(accounts, 30000);

        Test.setMock(HttpCalloutMock.class, new CreditServiceMock(false));

        Test.startTest();
        AccountPriorityService.calculatePriority(accounts);
        Test.stopTest();

        System.assertEquals(53, accounts[0].Priority_Score__c, '30000/10000 + 50 = 53.');
    }

    @isTest
    static void testExtreme_EmptyList_NoOpSafe() {
        Test.setMock(HttpCalloutMock.class, new CreditServiceMock(false));

        Test.startTest();
        AccountPriorityService.calculatePriority(new List<Account>());
        Test.stopTest();

        System.assertEquals(0, Limits.getCallouts(), 'An empty batch must not attempt any callouts or queries.');
    }
}

/*
 * -----------------------------------------------------------------------
 * 7) Riesgos futuros identificados (para el documento de estrategia)
 * -----------------------------------------------------------------------
 * - HALLAZGO CRITICO (bloqueante, no solo de escala): AccountTrigger llama a
 *   AccountPriorityService.calculatePriority() en contexto "before update", y
 *   ese método hace un callout HTTP. Salesforce PROHÍBE callouts síncronos
 *   desde triggers ("Callout from triggers are currently not supported"),
 *   sin excepción. Como el callout está en un try/catch que convierte la
 *   excepción en account.addError(...), CUALQUIER update a un Account (uno
 *   solo, no hace falta bulk) falla hoy en producción. Confirmado por
 *   testProductionRisk_TriggerInvocationFailsOnEveryAccountUpdate. La suite
 *   original (AccountPriorityTest) nunca lo detectó porque llama al método
 *   directamente y nunca hace un `update` real sobre Account.
 *   Mitigación: mover el callout fuera del contexto síncrono del trigger --
 *   encolar un Queueable desde el trigger (after update) que llame a
 *   calculatePriority() de forma asíncrona, o llamarlo desde un Batch/Flow
 *   fuera del antes-guardar. Esto también resuelve el hallazgo siguiente.
 * - RIESGO DE ESCALA (una vez arreglado lo anterior): con el límite de 100
 *   callouts síncronos, cualquier ejecución de calculatePriority() sobre
 *   más de 100 cuentas deja el 50%+ restante con credit rating = 0 de forma
 *   silenciosa -- sin excepción, sin log. Confirmado por
 *   testBulk_200Accounts_ExposesCalloutCeiling. Mitigación: procesar en
 *   chunks de <=100 en transacciones/ejecuciones separadas (demostrado en
 *   testTransaction1_/testTransaction2_), o cambiar a un callout bulk si el
 *   API externo lo soporta.
 * - Sin timeout explícito (`req.setTimeout(...)`) en getCreditRating(); un
 *   endpoint lento podría acercar la transacción al límite de tiempo
 *   agregado de callouts (120s) o al límite de CPU síncrono en un batch
 *   grande, incluso dentro del presupuesto de 100 llamadas.
 * - El guard `Limits.getCallouts() < Limits.getLimitCallouts()` asume que
 *   nada más en la misma transacción consume presupuesto de callouts. Si en
 *   el futuro otro trigger/Flow sobre Account agrega callouts propios, el
 *   número real de cuentas con credit rating válido bajará por debajo de
 *   100 sin que este código lo sepa.
 */
