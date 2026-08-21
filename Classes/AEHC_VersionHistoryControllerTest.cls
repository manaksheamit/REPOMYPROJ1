@isTest
public class AEHC_VersionHistoryControllerTest {
    
    @testSetup
    static void setupData() {
        
        Id rtId = Schema.SObjectType.AEHC_Asset__c
            .getRecordTypeInfosByDeveloperName()
            .get('AEHC_Application')
            .getRecordTypeId();
        
        // ✅ Create Subscription (used as recordId)
        Subscription__c sub = new Subscription__c(
            AEHC_Environment__c = 'Dev'
        );
        insert sub;
        
        // ✅ Create multiple Asset versions linked to same Subscription
        List<AEHC_Asset__c> assets = new List<AEHC_Asset__c>();
        
        for (Integer i = 1; i <= 3; i++) {
            assets.add(new AEHC_Asset__c(
                Name = 'Version ' + i,
                AEHC_Is_Active__c = (i == 3), // latest active
                AEHC_Environment__c = 'Dev',
                AEHC_Schema_Version__c = String.valueOf(i),
                AEHC_Subscription_Request__c = sub.Id,
                RecordTypeId = rtId
            ));
        }
        
        insert assets;
    }
    
    @isTest
    static void testGetVersionHistory_WithData() {
        
        // ✅ Get Subscription Id
        Subscription__c sub = [SELECT Id FROM Subscription__c LIMIT 1];
        
        Test.startTest();
        
        List<AEHC_VersionHistoryController.VersionHistoryWrapper> result =
            AEHC_VersionHistoryController.getVersionHistory(sub.Id);
        
        Test.stopTest();
        
        // ✅ Assertions
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.size() > 0, 'Should return version records');
        
        for (AEHC_VersionHistoryController.VersionHistoryWrapper rec : result) {
            
            System.assertNotEquals(null, rec.name);
            System.assertNotEquals(null, rec.environment);
            System.assertNotEquals(null, rec.isActive);
            System.assertNotEquals(null, rec.schemaVersion);
            System.assertNotEquals(null, rec.lastModifieddate);
        }
    }
    
    @isTest
    static void testGetVersionHistory_NoData() {
        
        // ✅ Create a new Subscription with NO assets
        Subscription__c sub = new Subscription__c(
            AEHC_Environment__c = 'UAT'
        );
        insert sub;
        
        Test.startTest();
        
        List<AEHC_VersionHistoryController.VersionHistoryWrapper> result =
            AEHC_VersionHistoryController.getVersionHistory(sub.Id);
        
        Test.stopTest();
        
        // ✅ Assertions
        System.assertNotEquals(null, result);
        System.assertEquals(0, result.size(), 'Should return empty list');
    }
    
    
    
    @isTest
    static void testGetVersionId() {
        
        // ✅ Get existing test setup data (created in @testSetup)
        Subscription__c sub = [SELECT Id FROM Subscription__c WHERE AEHC_Environment__c = 'Dev' LIMIT 1];
        
        // ✅ Get an asset with known version
        AEHC_Asset__c asset = [
            SELECT Id, AEHC_Schema_Version__c
            FROM AEHC_Asset__c
            WHERE AEHC_Subscription_Request__c = :sub.Id
            AND AEHC_Environment__c = 'Dev'
            LIMIT 1
        ];
        
        Test.startTest();
        
        String resultId = AEHC_VersionHistoryController.getVersionId(
            sub.Id,          // ✅ correct parameter
            'Dev',
            asset.AEHC_Schema_Version__c   // ✅ pass matching version
        );
        
        Test.stopTest();
        
        // ✅ Assertions
        System.assertNotEquals(null, resultId, 'Returned Id should not be null');
        System.assertEquals(asset.Id, resultId, 'Should return correct Asset Id');
    }
    
    @IsTest
    static void testGetVersionHistory_Publication() {
        
        Id pubRtId = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'AEHC_Asset__c'
            AND DeveloperName = 'AEHC_Publication'
            LIMIT 1
        ].Id;
        
        Id verRtId = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'AEHC_Asset__c'
            AND DeveloperName = 'AEHC_Version'
            LIMIT 1
        ].Id;
        
        AEHC_Asset__c publication = new AEHC_Asset__c(
            Name = 'Test Publication',
            RecordTypeId = pubRtId
        );
        insert publication;
        
        insert new AEHC_Asset__c(
            Name = 'Version 1',
            RecordTypeId = verRtId,
            AEHC_Publication__c = publication.Id,
            AEHC_Environment__c = 'Dev',
            AEHC_Schema_Version__c = '1',
            AEHC_Is_Active__c = true,
            AEHC_Is_Subscription__c = false
        );
        
        Test.startTest();
        
        List<AEHC_VersionHistoryController.VersionHistoryWrapper> result =
            AEHC_VersionHistoryController.getVersionHistory(
                publication.Id
            );
        
        Test.stopTest();
        
        System.assertEquals(1, result.size());
        System.assertEquals('Dev', result[0].environment);
    }
    
    @IsTest
    static void testGetVersionHistory_NullId() {
        
        Test.startTest();
        
        List<AEHC_VersionHistoryController.VersionHistoryWrapper> result =
            AEHC_VersionHistoryController.getVersionHistory(null);
        
        Test.stopTest();
        
        System.assertEquals(0, result.size());
    }
    
    @IsTest
    static void testGetVersionHistory_Version() {
        
        Id verRtId = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'AEHC_Asset__c'
            AND DeveloperName = 'AEHC_Version'
            LIMIT 1
        ].Id;
        
        AEHC_Asset__c ver = new AEHC_Asset__c(
            Name = 'Version 1',
            RecordTypeId = verRtId,
            AEHC_Environment__c = 'Dev',
            AEHC_Schema_Version__c = '1',
            AEHC_Is_Active__c = true,
            AEHC_Is_Subscription__c = false
        );
        insert ver;
        
        Test.startTest();
        
        List<AEHC_VersionHistoryController.VersionHistoryWrapper> result =
            AEHC_VersionHistoryController.getVersionHistory(
                ver.Id
            );
        
        Test.stopTest();
        
    }
    
}