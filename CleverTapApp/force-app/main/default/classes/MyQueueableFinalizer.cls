/**
 * @class MyQueueableFinalizer
 * @description Implements post-processing logic for the SendLeadToCleverTapQueueable job.
 */
public class MyQueueableFinalizer {
    /**
     * @description Executes finalizer logic after the Queueable job completes.
     * @param context The Queueable context.
     */
    @SuppressWarnings('PMD.AvoidDebugStatements')
    public void executeFinalizer(QueueableContext context) {
        // Logging or any cleanup logic can go here
        System.debug(LoggingLevel.INFO, 'Finalizer executed for SendLeadToCleverTapQueueable.');
    }
}