public with sharing class CleverTapService {
    /**
     * @description Sends the provided Lead record to CleverTap.
     * @param lead The Salesforce Lead record to be sent.
     */
    public static void sendLeadToCleverTap(Lead lead) {
        try {
            // Check if there's an active sync configuration for Lead
            CleverTap_Sync_Configuration__c syncConfig = [
                SELECT Id, Name, Status__c 
                FROM CleverTap_Sync_Configuration__c 
                WHERE Salesforce_Entity__c = 'Lead' 
                AND Status__c = 'Active' 
                LIMIT 1
            ];

            if (syncConfig == null) {
                System.debug('No active sync configuration found for Lead');
                return;
            }

            // Get credentials from custom metadata
            Map<String, String> credentials = CleverTapConfig.getCredentials();
            if (credentials == null || credentials.isEmpty()) {
                System.debug('CleverTap credentials not found');
                return;
            }

            // Map the lead using configured field mappings
            Map<String, Object> mappedLead = CleverTapLeadMapper.mapLeadToCleverTap(lead);
            if (mappedLead == null) {
                System.debug('Lead mapping returned null');
                return;
            }

            // Prepare JSON payload
            Map<String, Object> payload = new Map<String, Object>{
                'd' => new List<Map<String, Object>>{mappedLead}
            };
            String jsonBody = JSON.serialize(payload);

            // Create and validate CleverTap request
            CleverTapRequest request = new CleverTapRequest(credentials, jsonBody);
            if (request.hasMissingCredentials()) {
                System.debug('Missing required credentials');
                return;
            }

            // Send HTTP Request
            HttpRequest req = new HttpRequest();
            req.setEndpoint(request.apiUrl);
            req.setMethod('POST');
            req.setTimeout(120000); // Set timeout to 120 seconds

            // Set headers
            for (String headerKey : request.headers.keySet()) {
                req.setHeader(headerKey, request.headers.get(headerKey));
            }
            req.setBody(request.jsonBody);

            // Send request and get response
            Http http = new Http();
            HttpResponse res = http.send(req);

            // Log the event
            logCleverTapEvent(lead.Id, res, jsonBody);

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error sending lead to CleverTap: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            
            // Log error event
            logCleverTapEvent(
                lead.Id, 
                null, 
                'Error: ' + e.getMessage()
            );
        }
    }

    /**
     * @description Logs the CleverTap event response
     * @param leadId The Lead record Id
     * @param response The HTTP response
     * @param requestBody The request body sent
     */
    private static void logCleverTapEvent(
        Id leadId, 
        HttpResponse response, 
        String requestBody
    ) {
        try {
            if (Schema.sObjectType.CleverTap_Event__c.isCreateable()) {
                CleverTap_Event__c eventLog = new CleverTap_Event__c(
                    Lead__c = leadId,
                    Status__c = (response != null && response.getStatusCode() == 200) 
                        ? 'Success' 
                        : 'Failed',
                    Response__c = response != null 
                        ? response.getBody() + '\nRequest: ' + requestBody 
                        : requestBody
                );
                
                insert eventLog;
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error logging CleverTap event: ' + e.getMessage());
        }
    }
}