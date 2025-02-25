trigger SendLeadToCleverTap on Lead (after insert, after update) {
    SendLeadToCleverTapHandler.processLeads(Trigger.new);
}


