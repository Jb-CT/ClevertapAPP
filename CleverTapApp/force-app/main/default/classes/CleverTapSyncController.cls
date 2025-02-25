public with sharing class CleverTapSyncController {
    
    public class SyncConfigWrapper {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String syncType { get; set; }
        @AuraEnabled public String salesforceEntity { get; set; }
        @AuraEnabled public String clevertapEntity { get; set; }
        @AuraEnabled public String status { get; set; }
        
        public SyncConfigWrapper(CleverTap_Sync_Configuration__c config) {
            System.debug('Creating wrapper from config: ' + JSON.serialize(config));
            
            this.id = config.Id;
            this.name = config.Name;
            this.syncType = config.Sync_Type__c;
            this.salesforceEntity = config.Salesforce_Entity__c;
            this.clevertapEntity = config.CleverTap_Entity__c;
            this.status = config.Status__c;
            
            System.debug('Created wrapper with values: ' + JSON.serialize(this));
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<SyncConfigWrapper> getSyncConfigurations() {
        try {
            List<CleverTap_Sync_Configuration__c> configs = [
                SELECT Id, Name, Sync_Type__c, 
                       Salesforce_Entity__c, CleverTap_Entity__c, 
                       Status__c
                FROM CleverTap_Sync_Configuration__c
                ORDER BY CreatedDate DESC
            ];
            
            List<SyncConfigWrapper> wrappers = new List<SyncConfigWrapper>();
            for (CleverTap_Sync_Configuration__c config : configs) {
                wrappers.add(new SyncConfigWrapper(config));
            }
            return wrappers;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching sync configurations: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getPicklistValues(String objectName, String fieldName) {
        List<Map<String, String>> picklistOptions = new List<Map<String, String>>();
        try {
            Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectName);
            if (objectType == null) {
                throw new AuraHandledException('Invalid object name: ' + objectName);
            }
    
            Schema.DescribeFieldResult fieldDescribe = objectType.getDescribe().fields.getMap().get(fieldName).getDescribe();
            if (fieldDescribe == null || !fieldDescribe.isAccessible()) {
                throw new AuraHandledException('Invalid or inaccessible field: ' + fieldName);
            }
    
            for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
                Map<String, String> option = new Map<String, String>();
                option.put('label', entry.getLabel());
                option.put('value', entry.getValue());
                picklistOptions.add(option);
            }
            return picklistOptions;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching picklist values: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void saveFieldMappings(String mappingData) {
        Savepoint sp = Database.setSavepoint();
        try {
            // Debug incoming data
            System.debug('Received mapping data: ' + mappingData);
            
            if (String.isBlank(mappingData)) {
                throw new AuraHandledException('Mapping data cannot be empty');
            }

            // Parse the mapping data
            Map<String, Object> mappingsMap;
            try {
                mappingsMap = (Map<String, Object>)JSON.deserializeUntyped(mappingData);
            } catch (Exception e) {
                throw new AuraHandledException('Invalid JSON format: ' + e.getMessage());
            }

            // Validate syncId
            Id syncId;
            try {
                syncId = (Id)mappingsMap.get('syncId');
                if (syncId == null) {
                    throw new AuraHandledException('SyncId is required');
                }
            } catch (Exception e) {
                throw new AuraHandledException('Invalid syncId: ' + e.getMessage());
            }

            // Get and validate mappings
            List<Object> mappingsObj = (List<Object>)mappingsMap.get('mappings');
            if (mappingsObj == null || mappingsObj.isEmpty()) {
                throw new AuraHandledException('No mappings provided');
            }

            // Delete existing mappings
            try {
                delete [SELECT Id FROM CleverTap_Mapping__c WHERE Sync_Configuration__c = :syncId];
            } catch (Exception e) {
                throw new AuraHandledException('Error deleting existing mappings: ' + e.getMessage());
            }
            
            // Create new mappings
            List<CleverTap_Mapping__c> newMappings = new List<CleverTap_Mapping__c>();
            
            for(Object mappingObj : mappingsObj) {
                Map<String, Object> mapping = (Map<String, Object>)mappingObj;
                
                // Debug each mapping
                System.debug('Processing mapping: ' + mapping);

                // Validate required fields
                String clevertapField = (String)mapping.get('CleverTap_Field__c');
                String salesforceField = (String)mapping.get('Salesforce_Field__c');
                
                if (String.isBlank(clevertapField)) {
                    throw new AuraHandledException('CleverTap field name is required');
                }
                if (String.isBlank(salesforceField)) {
                    throw new AuraHandledException('Salesforce field name is required');
                }

                CleverTap_Mapping__c newMapping = new CleverTap_Mapping__c(
                    Sync_Configuration__c = syncId,
                    CleverTap_Field__c = clevertapField,
                    Salesforce_Field__c = salesforceField,
                    Data_Type__c = (String)mapping.get('Data_Type__c'),
                    Is_Mandatory__c = (Boolean)mapping.get('Is_Mandatory__c')
                );
                
                // Debug new mapping record
                System.debug('Created mapping record: ' + newMapping);
                
                newMappings.add(newMapping);
            }
            
            // Insert new mappings with error checking
            try {
                insert newMappings;
            } catch (Exception e) {
                throw new AuraHandledException('Error inserting new mappings: ' + e.getMessage());
            }

        } catch (Exception e) {
            // Rollback on error
            Database.rollback(sp);
            
            // Log the full error details
            System.debug('Error in saveFieldMappings: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            
            // Throw user-friendly error
            String errorMsg = 'Error saving mappings: ' + e.getMessage();
            System.debug(errorMsg);
            throw new AuraHandledException(errorMsg);
        }
    }
    
    @AuraEnabled
    public static void deleteSyncConfiguration(String syncId) {
        try {
            CleverTap_Sync_Configuration__c config = [
                SELECT Id FROM CleverTap_Sync_Configuration__c WHERE Id = :syncId LIMIT 1
            ];
            delete config;
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting sync configuration: ' + e.getMessage());
        }
    }
    @AuraEnabled
    public static List<CleverTap_Mapping__c> getExistingMappings(Id syncId) {
        return [
            SELECT Id, CleverTap_Field__c, Salesforce_Field__c, 
                   Data_Type__c, Is_Mandatory__c
            FROM CleverTap_Mapping__c
            WHERE Sync_Configuration__c = :syncId
        ];
    }

    @AuraEnabled
    public static void updateSyncStatus(String syncId, String status) {
        try {
            CleverTap_Sync_Configuration__c config = [
                SELECT Id, Status__c FROM CleverTap_Sync_Configuration__c WHERE Id = :syncId LIMIT 1
            ];
            config.Status__c = status;
            update config;
        } catch (Exception e) {
            throw new AuraHandledException('Error updating sync status: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String createSyncConfiguration(String syncData) {
        try {
            Map<String, Object> syncMap = (Map<String, Object>) JSON.deserializeUntyped(syncData);
            
            CleverTap_Sync_Configuration__c syncConfig = new CleverTap_Sync_Configuration__c(
                Name = (String) syncMap.get('name'),
                Sync_Type__c = (String) syncMap.get('syncType'),
                Salesforce_Entity__c = (String) syncMap.get('salesforceEntity'),
                CleverTap_Entity__c = (String) syncMap.get('clevertapEntity'),
                Status__c = 'Active'  // Changed to Active
            );
            
            insert syncConfig;
            return syncConfig.Id;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error creating sync configuration: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getSalesforceFields(String objectName) {
        List<Map<String, String>> fields = new List<Map<String, String>>();
        try {
            if (String.isBlank(objectName)) {
                throw new AuraHandledException('Object name cannot be blank');
            }
            Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectName);
            if (objectType == null) {
                throw new AuraHandledException('Invalid object name: ' + objectName);
            }
            Map<String, Schema.SObjectField> fieldMap = objectType.getDescribe().fields.getMap();
            for (String fieldName : fieldMap.keySet()) {
                Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
                if (fieldDescribe.isAccessible()) {
                    Map<String, String> fieldInfo = new Map<String, String>();
                    fieldInfo.put('label', fieldDescribe.getLabel());
                    fieldInfo.put('value', fieldDescribe.getName());
                    fields.add(fieldInfo);
                }
            }
            return fields;
        } catch (Exception e) {
            throw new AuraHandledException('Error getting fields: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static SyncConfigWrapper getSyncConfigurationById(String syncId) {
        try {
            System.debug('Entering getSyncConfigurationById with syncId: ' + syncId);
            
            CleverTap_Sync_Configuration__c config = [
                SELECT Id, Name, Sync_Type__c, 
                       Salesforce_Entity__c, CleverTap_Entity__c, 
                       Status__c
                FROM CleverTap_Sync_Configuration__c
                WHERE Id = :syncId
                LIMIT 1
            ];
            
            System.debug('Retrieved config: ' + JSON.serialize(config));
            
            SyncConfigWrapper wrapper = new SyncConfigWrapper(config);
            System.debug('Created wrapper: ' + JSON.serialize(wrapper));
            
            return wrapper;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error in getSyncConfigurationById: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error fetching sync configuration: ' + e.getMessage());
        }
    }

    @AuraEnabled
public static SyncConfigWrapper updateSyncConfiguration(String syncId, String syncData) {
    try {
        Map<String, Object> syncMap = (Map<String, Object>) JSON.deserializeUntyped(syncData);
        
        CleverTap_Sync_Configuration__c syncConfig = [
            SELECT Id FROM CleverTap_Sync_Configuration__c 
            WHERE Id = :syncId 
            LIMIT 1
        ];
        
        syncConfig.Name = (String) syncMap.get('name');
        syncConfig.Sync_Type__c = (String) syncMap.get('syncType');
        syncConfig.Salesforce_Entity__c = (String) syncMap.get('salesforceEntity');
        syncConfig.CleverTap_Entity__c = (String) syncMap.get('clevertapEntity');
        
        update syncConfig;
        
        // Return the updated record
        return new SyncConfigWrapper([
            SELECT Id, Name, Sync_Type__c, 
                   Salesforce_Entity__c, CleverTap_Entity__c, 
                   Status__c
            FROM CleverTap_Sync_Configuration__c
            WHERE Id = :syncId
            LIMIT 1
        ]);
    } catch (Exception e) {
        throw new AuraHandledException('Error updating sync configuration: ' + e.getMessage());
    }
}
}