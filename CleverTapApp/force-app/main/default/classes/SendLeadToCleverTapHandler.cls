/**
 * @class SendLeadToCleverTapHandler
 * @description Handles processing of Lead records by enqueuing an asynchronous job.
 */
public with sharing class SendLeadToCleverTapHandler {
    /**
     * @description Processes a list of Lead records by enqueuing them for asynchronous CleverTap integration.
     * @param leads The list of Lead records to process.
     */
    public static void processLeads(List<Lead> leads) {
        if (leads == null || leads.isEmpty()) {
            // Removed debug statement to avoid performance violation
            return;
        }
        System.enqueueJob(new SendLeadToCleverTapQueueable(leads));
    }
}


