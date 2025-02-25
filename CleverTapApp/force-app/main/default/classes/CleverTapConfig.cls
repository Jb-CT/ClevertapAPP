/**
 * @class CleverTapConfig
 * @description Provides configuration settings for the CleverTap integration by retrieving API credentials from custom metadata.
 */
public with sharing class CleverTapConfig {
    
    /**
     * @description Retrieves CleverTap API credentials for a specific configuration.
     * @param configName The name of the configuration to retrieve
     * @return Map<String, String> containing keys 'API_URL', 'ACCOUNT_ID', and 'PASSCODE', or null if not accessible.
     */
    public static Map<String, String> getCredentials(String configName) {
        // Ensure the user has read access to CleverTap_Config__mdt
        if (!Schema.sObjectType.CleverTap_Config__mdt.isAccessible()) {
            return null;
        }

        if (String.isBlank(configName)) {
            return null;
        }

        List<CleverTap_Config__mdt> configList = [
            SELECT CleverTap_API_URL__c, CleverTap_Account_ID__c, CleverTap_Passcode__c 
            FROM CleverTap_Config__mdt 
            WHERE DeveloperName = :configName
            AND MasterLabel != '[Deleted]'
            LIMIT 1
        ];

        if (configList.isEmpty()) {
            return null;
        }

        CleverTap_Config__mdt config = configList[0];

        Map<String, String> credentials = new Map<String, String>{
            'API_URL'    => config.CleverTap_API_URL__c,
            'ACCOUNT_ID' => config.CleverTap_Account_ID__c,
            'PASSCODE'   => config.CleverTap_Passcode__c
        };
        return credentials;
    }

    /**
     * @description Retrieves all available CleverTap configurations.
     * @return List<Map<String, String>> containing the credentials for all active configurations.
     */
    public static List<Map<String, String>> getAllCredentials() {
        if (!Schema.sObjectType.CleverTap_Config__mdt.isAccessible()) {
            return new List<Map<String, String>>();
        }

        List<CleverTap_Config__mdt> configList = [
            SELECT DeveloperName, MasterLabel, CleverTap_API_URL__c, 
                   CleverTap_Account_ID__c, CleverTap_Passcode__c 
            FROM CleverTap_Config__mdt 
            WHERE MasterLabel != '[Deleted]'
            ORDER BY MasterLabel
        ];

        List<Map<String, String>> allCredentials = new List<Map<String, String>>();
        
        for (CleverTap_Config__mdt config : configList) {
            Map<String, String> credentials = new Map<String, String>{
                'NAME'       => config.MasterLabel,
                'DEV_NAME'   => config.DeveloperName,
                'API_URL'    => config.CleverTap_API_URL__c,
                'ACCOUNT_ID' => config.CleverTap_Account_ID__c,
                'PASSCODE'   => config.CleverTap_Passcode__c
            };
            allCredentials.add(credentials);
        }

        return allCredentials;
    }

    /**
     * @description Gets the default configuration if no specific configuration is specified.
     * @return Map<String, String> containing the credentials for the first active configuration.
     */
    public static Map<String, String> getCredentials() {
        List<Map<String, String>> allCreds = getAllCredentials();
        if (!allCreds.isEmpty()) {
            return allCreds[0];
        }
        return null;
    }
}