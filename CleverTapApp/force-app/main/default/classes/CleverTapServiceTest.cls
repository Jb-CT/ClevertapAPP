@isTest
private class CleverTapServiceTest {
    @isTest
    static void testSendLeadWithMissingCredentials() {
        // Create a test lead
        Lead testLead = new Lead(
            FirstName = 'Jane',
            LastName = 'Doe',
            Company = 'Test Corp',
            Email = 'janedoe@example.com',
            Phone = '+1234567890',
            LeadSource = 'Web',
            Status = 'New'
        );
        insert testLead;

        // Test scenario where credentials are missing
        Test.startTest();
        CleverTapService.sendLeadToCleverTap(testLead);
        Test.stopTest();

        // Verify that no event is created when credentials are missing
        List<CleverTap_Event__c> events = [SELECT Id FROM CleverTap_Event__c WHERE Lead__c = :testLead.Id];
        System.assert(events.isEmpty(), 'No event should be created if credentials are missing.');
    }
}