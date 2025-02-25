/**
 * @class SendLeadToCleverTapQueueable
 * @description A Queueable class that processes one or more Lead records and sends them to CleverTap.
 */
@SuppressWarnings('PMD.QueueableWithoutFinalizer')
public class SendLeadToCleverTapQueueable implements Queueable, Database.AllowsCallouts {
    private List<Lead> leadRecords;

    /**
     * @description Constructor for processing a single Lead.
     * @param lead A single Salesforce Lead record.
     */
    public SendLeadToCleverTapQueueable(Lead lead) {
        this.leadRecords = new List<Lead>{lead};
    }

    /**
     * @description Constructor for processing multiple Leads.
     * @param leads A list of Salesforce Lead records.
     */
    public SendLeadToCleverTapQueueable(List<Lead> leads) {
        this.leadRecords = leads;
    }

    /**
     * @description Executes the job to send each Lead to CleverTap.
     * @param context The Queueable context.
     */
    public void execute(QueueableContext context) {
        for (Lead lead : leadRecords) {
            CleverTapService.sendLeadToCleverTap(lead);
        }
    }
}