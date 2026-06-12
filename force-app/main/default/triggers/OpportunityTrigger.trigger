trigger OpportunityTrigger on Opportunity (after update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        OpportunityCommissionHandler.handleClosedWonOpportunities(Trigger.new, Trigger.oldMap);
    }
}