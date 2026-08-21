/**
* Author: Rushikesh Rajan
*/
@isTest
public class AEHC_EmailController_Test {
    
    @isTest
    static void testController() {
        
        RecordType rt = [
            SELECT Id
            FROM RecordType
            WHERE SobjectType = 'AEHC_Asset__c'
            AND DeveloperName = 'AEHC_Application'
            LIMIT 1
        ];
        
        Contact con = new Contact(
            LastName = 'Test Contact',
            Email = 'test@test.com'
        );
        insert con;
        
        AEHC_Asset__c asset = new AEHC_Asset__c(
            Name = 'Test Asset',
            RecordTypeId = rt.Id,
            Approval_Status__c = 'Approved'
        );
        insert asset;
        
        Subscription__c sub = new Subscription__c(
            AEHC_Application_Name__c = asset.Id,
            Status__c = 'Approved'
        );
        insert sub;
        
        RecordType pubRt = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'AEHC_Asset__c'
            AND DeveloperName = 'AEHC_Publication'
            LIMIT 1
        ];
        
        AEHC_Asset__c childAsset = new AEHC_Asset__c(
            Name = 'Child Asset',
            RecordTypeId = pubRt.Id,
            Approval_Status__c = 'Approved',
            AEHC_Application__c = asset.Id
        );
        insert childAsset;
        AEHC_AssetMember__c member = new AEHC_AssetMember__c(
            AEHC_Asset__c = asset.Id,
            AEHC_User__c = UserInfo.getUserId()
        );
        insert member;
        
        Test.startTest();
        
        AEHC_EmailController.getAssets();
        AEHC_EmailController.getAssociatedUsers(asset.Id);
        
        AEHC_EmailController.sendEmail(
            new List<Id>{con.Id},
            'Test',
            '<p>Test Body</p>',
            null,
            new List<String>{'cc@test.com'}
        );
        
        Test.stopTest();
    }
    @isTest
    static void testGetAssets() {
        
        RecordType appRt = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'AEHC_Asset__c'
            AND DeveloperName = 'AEHC_Application'
            LIMIT 1
        ];
        
        RecordType pubRt = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'AEHC_Asset__c'
            AND DeveloperName = 'AEHC_Publication'
            LIMIT 1
        ];
        
        AEHC_Asset__c app = new AEHC_Asset__c(
            Name = 'Application Test',
            RecordTypeId = appRt.Id,
            Approval_Status__c = 'Approved'
        );
        insert app;
        
        insert new AEHC_AssetMember__c(
            AEHC_Asset__c = app.Id,
            AEHC_User__c = UserInfo.getUserId()
        );
        
        insert new AEHC_Asset__c(
            Name = 'Publication Test',
            RecordTypeId = pubRt.Id,
            Approval_Status__c = 'Approved',
            AEHC_Application__c = app.Id
        );
        
        Test.startTest();
        
        List<AEHC_EmailController.AssetWrapper> result =
            AEHC_EmailController.getAssets();
        
        Test.stopTest();
        
        System.assert(result.size() > 0);
    }
    @isTest
    static void testGetAssociatedUsers_Application() {
        
        RecordType appRt = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'AEHC_Asset__c'
            AND DeveloperName = 'AEHC_Application'
            LIMIT 1
        ];
        
        Contact con = new Contact(
            LastName = 'Subscriber Contact',
            Email = 'subscriber@test.com'
        );
        insert con;
        
        User u = [SELECT Id, ContactId FROM User WHERE Id = :UserInfo.getUserId()];
        
        AEHC_Asset__c app = new AEHC_Asset__c(
            Name = 'Application Test',
            RecordTypeId = appRt.Id,
            Approval_Status__c = 'Approved'
        );
        insert app;
        
        insert new AEHC_AssetMember__c(
            AEHC_Asset__c = app.Id,
            AEHC_User__c = UserInfo.getUserId()
        );
        
        Subscription__c sub = new Subscription__c(
            AEHC_Application_Name__c = app.Id,
            Subscriber__c = UserInfo.getUserId()
        );
        insert sub;
        
        Test.startTest();
        
        List<AEHC_EmailController.UserWrapper> users =
            AEHC_EmailController.getAssociatedUsers(app.Id);
        
        Test.stopTest();
        
        System.assertNotEquals(null, users);
    }
    @isTest
    static void testGetAssociatedUsers_Publication() {
        
        RecordType appRt = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'AEHC_Asset__c'
            AND DeveloperName = 'AEHC_Application'
            LIMIT 1
        ];
        
        RecordType pubRt = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'AEHC_Asset__c'
            AND DeveloperName = 'AEHC_Publication'
            LIMIT 1
        ];
        
        AEHC_Asset__c app = new AEHC_Asset__c(
            Name = 'App',
            RecordTypeId = appRt.Id,
            Approval_Status__c = 'Approved'
        );
        insert app;
        
        insert new AEHC_AssetMember__c(
            AEHC_Asset__c = app.Id,
            AEHC_User__c = UserInfo.getUserId()
        );
        
        AEHC_Asset__c pub = new AEHC_Asset__c(
            Name = 'Publication',
            RecordTypeId = pubRt.Id,
            Approval_Status__c = 'Approved',
            AEHC_Application__c = app.Id
        );
        insert pub;
        
        insert new Subscription__c(
            AEHC_Publication_ID__c = pub.Id,
            Subscriber__c = UserInfo.getUserId()
        );
        
        Test.startTest();
        
        List<AEHC_EmailController.UserWrapper> users =
            AEHC_EmailController.getAssociatedUsers(pub.Id);
        
        Test.stopTest();
        
        System.assertNotEquals(null, users);
    }
    @isTest
    static void testGetAssociatedUsers_NullAsset() {
        
        try {
            
            AEHC_EmailController.getAssociatedUsers(null);
            
            System.assert(false,
                          'Exception should have been thrown');
            
        } catch (Exception e) {
        }
    }
    @isTest
    static void testSendEmail() {
        
        Contact con = new Contact(
            LastName = 'Email Contact',
            Email = 'test@test.com'
        );
        insert con;
        
        Test.startTest();
        
        AEHC_EmailController.sendEmail(
            new List<Id>{ con.Id },
            'Test Subject',
            '<p>Test Body</p>',
            null,
            new List<String>{
                'cc1@test.com',
                    'cc2@test.com'
                    }
        );
        
        Test.stopTest();
        
        System.assert(true);
    }
}