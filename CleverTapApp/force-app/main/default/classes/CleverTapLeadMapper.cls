public with sharing class CleverTapLeadMapper {
    /**
     * @description Maps a given Lead record to a CleverTap payload using field mappings.
     * @param lead The Salesforce Lead record.
     * @return A Map<String, Object> representing the CleverTap payload, or null if the lead is null.
     */
    public static Map<String, Object> mapLeadToCleverTap(Lead lead) {
        if (lead == null) return null;
        
        try {
            // Get sync configuration and field mappings
            List<CleverTap_Mapping__c> fieldMappings = [
                SELECT Id, CleverTap_Field__c, Salesforce_Field__c, 
                       Data_Type__c, Is_Mandatory__c
                FROM CleverTap_Mapping__c
                WHERE Sync_Configuration__c IN (
                    SELECT Id FROM CleverTap_Sync_Configuration__c 
                    WHERE Salesforce_Entity__c = 'Lead' 
                    AND Status__c = 'Active'
                )
            ];
            
            if (fieldMappings.isEmpty()) return null;
            
            // Find the mandatory customer_id mapping
            CleverTap_Mapping__c identityMapping;
            for(CleverTap_Mapping__c mapping : fieldMappings) {
                if(mapping.Is_Mandatory__c && mapping.CleverTap_Field__c == 'customer_id') {
                    identityMapping = mapping;
                    break;
                }
            }
            
            if (identityMapping == null) return null;
            
            // Get the identity value using the mapped Salesforce field
            String identityValue = String.valueOf(lead.get(identityMapping.Salesforce_Field__c));
            if (String.isBlank(identityValue)) return null;
            
            // Build payload using only mapped fields
            Map<String, Object> payload = new Map<String, Object>();
            Map<String, Object> profileData = new Map<String, Object>();
            
            // Add mapped fields to profile data
            for (CleverTap_Mapping__c mapping : fieldMappings) {
                Object fieldValue = lead.get(mapping.Salesforce_Field__c);
                
                if (fieldValue != null) {
                    // Convert the field value based on data type
                    Object convertedValue = convertFieldValue(fieldValue, mapping.Data_Type__c);
                    profileData.put(mapping.CleverTap_Field__c, convertedValue);
                }
            }
            
            // Add required CleverTap fields
            //profileData.put('Source', 'Salesforce');
            profileData.put('Timestamp', DateTime.now().format());
            
            // Build final payload
            payload.put('identity', identityValue);
            payload.put('type', 'profile');
            payload.put('$source', 'SFDC');
            payload.put('profileData', profileData);
            
            return payload;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error mapping lead to CleverTap: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * @description Converts a field value to the appropriate type for CleverTap.
     * @param value The field value to convert.
     * @param dataType The target data type.
     * @return The converted value.
     */
    private static Object convertFieldValue(Object value, String dataType) {
        if (value == null) return null;
        
        switch on dataType?.toLowerCase() {
            when 'number' {
                return Decimal.valueOf(String.valueOf(value));
            }
            when 'boolean' {
                return Boolean.valueOf(value);
            }
            when 'date' {
                if (value instanceof DateTime) {
                    return ((DateTime)value).format();
                } else if (value instanceof Date) {
                    return ((Date)value).format();
                }
                return String.valueOf(value);
            }
            when else {
                return String.valueOf(value);
            }
        }
    }
}