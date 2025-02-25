public with sharing class CleverTapConfigController {
    
    private static Map<String, String> REGION_TO_URL = new Map<String, String>{
        'US' => 'https://us1.api.clevertap.com/1/upload',
        'IN' => 'https://in1.api.clevertap.com/1/upload',
        'EU' => 'https://eu1.api.clevertap.com/1/upload'
    };
    
    @AuraEnabled(cacheable=true)
    public static List<CleverTap_Config__mdt> getConfig() {
        try {
            List<CleverTap_Config__mdt> configs = [
                SELECT DeveloperName, MasterLabel, CleverTap_Account_ID__c, 
                       CleverTap_Passcode__c, Region__c, CleverTap_API_URL__c
                FROM CleverTap_Config__mdt
                WHERE MasterLabel != '[Deleted]%'
                ORDER BY MasterLabel
            ];
            
            return configs;
        } catch (Exception e) {
            System.debug('Error fetching configurations: ' + e.getMessage());
            throw new AuraHandledException('Error fetching configurations: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String saveConfig(Map<String, Object> config) {
        try {
            if (!config.containsKey('name') || String.isBlank((String)config.get('name'))) {
                throw new AuraHandledException('Connection name is required');
            }

            String region = (String)config.get('region');
            if (String.isBlank(region)) {
                throw new AuraHandledException('Region is required');
            }

            Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
            
            Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
            String connectionName = (String)config.get('name');
            
            // If we're editing an existing record, use its developer name
            if (config.containsKey('developerName') && String.isNotBlank((String)config.get('developerName'))) {
                customMetadata.fullName = 'CleverTap_Config__mdt.' + (String)config.get('developerName');
            } else {
                // For new records, create developer name from connection name
                String safeName = connectionName.replaceAll('[^a-zA-Z0-9]', '_').replaceAll('_{2,}', '_');
                // Ensure it starts with a letter
                if (!safeName.substring(0,1).isAlpha()) {
                    safeName = 'CT_' + safeName;
                }
                // Truncate if necessary (max length is 40)
                if (safeName.length() > 40) {
                    safeName = safeName.substring(0, 40);
                }
                customMetadata.fullName = 'CleverTap_Config__mdt.' + safeName;
            }
            
            customMetadata.label = connectionName;

            List<Metadata.CustomMetadataValue> fields = new List<Metadata.CustomMetadataValue>();
            
            // Add Region field
            Metadata.CustomMetadataValue regionField = new Metadata.CustomMetadataValue();
            regionField.field = 'Region__c';
            regionField.value = region;
            fields.add(regionField);
            
            // Add Account ID field
            Metadata.CustomMetadataValue accountIdField = new Metadata.CustomMetadataValue();
            accountIdField.field = 'CleverTap_Account_ID__c';
            accountIdField.value = config.get('accountId');
            fields.add(accountIdField);
            
            // Add Passcode field
            Metadata.CustomMetadataValue passcodeField = new Metadata.CustomMetadataValue();
            passcodeField.field = 'CleverTap_Passcode__c';
            passcodeField.value = config.get('passcode');
            fields.add(passcodeField);
            
            // Add API URL field based on region
            Metadata.CustomMetadataValue apiUrlField = new Metadata.CustomMetadataValue();
            apiUrlField.field = 'CleverTap_API_URL__c';
            apiUrlField.value = REGION_TO_URL.get(region.toUpperCase());
            fields.add(apiUrlField);
            
            customMetadata.values = fields;
            mdContainer.addMetadata(customMetadata);

            if (!Test.isRunningTest()) {
                // Enqueue the deployment
                Id jobId = Metadata.Operations.enqueueDeployment(mdContainer, null);
                System.debug('Deployment Job ID: ' + jobId);
            }
            
            return 'Success';
        } catch (Exception e) {
            System.debug('Error saving configuration: ' + e.getMessage());
            throw new AuraHandledException('Error saving configuration: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String deleteConfig(String developerName) {
        try {
            if (String.isBlank(developerName)) {
                throw new AuraHandledException('Developer name is required for deletion');
            }

            // First, verify the record exists
            List<CleverTap_Config__mdt> existingConfigs = [
                SELECT Id, DeveloperName, MasterLabel 
                FROM CleverTap_Config__mdt 
                WHERE DeveloperName = :developerName
                LIMIT 1
            ];

            if (existingConfigs.isEmpty()) {
                throw new AuraHandledException('Configuration not found');
            }

            // Prepare the metadata deployment
            Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
            
            // Create metadata for updating the record
            Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
            customMetadata.fullName = 'CleverTap_Config__mdt.' + developerName;
            customMetadata.label = '[DELETED] ' + existingConfigs[0].MasterLabel;

            // Create a list to hold the field updates
            List<Metadata.CustomMetadataValue> fields = new List<Metadata.CustomMetadataValue>();
            
            // Clear all sensitive fields
            Map<String, String> fieldsToUpdate = new Map<String, String>{
                'CleverTap_Account_ID__c' => '',
                'CleverTap_Passcode__c' => '',
                'Region__c' => '',
                'CleverTap_API_URL__c' => ''
            };
            
            // Add each field to the metadata
            for (String fieldName : fieldsToUpdate.keySet()) {
                Metadata.CustomMetadataValue field = new Metadata.CustomMetadataValue();
                field.field = fieldName;
                field.value = fieldsToUpdate.get(fieldName);
                fields.add(field);
            }
            
            customMetadata.values = fields;
            mdContainer.addMetadata(customMetadata);

            if (!Test.isRunningTest()) {
                Id jobId = Metadata.Operations.enqueueDeployment(mdContainer, null);
                System.debug('Deletion deployment job ID: ' + jobId);
            }
            
            return 'Success';
        } catch (Exception e) {
            System.debug('Error in deleteConfig: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException(e.getMessage());
        }
    }
}