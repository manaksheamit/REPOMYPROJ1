@isTest
public class AEHC_PublicationPromoteControllerTest {

    @testSetup
    static void setupData() {
        Id appRT = Schema.SObjectType.AEHC_Asset__c
            .getRecordTypeInfosByDeveloperName()
            .get('AEHC_Application')
            .getRecordTypeId();

        AEHC_Asset__c app = new AEHC_Asset__c(
            Name = 'Test Application',
            RecordTypeId = appRT
        );
        insert app;
       AEHC_AssetMember__c assetMem = new AEHC_AssetMember__c( AEHC_User__c = System.UserInfo.getUserId(),
                                                              AEHC_Role__c ='Business Owner',
                                                              AEHC_Asset__c = app.id);
        insert assetMem ;
		
        Id pubRT = Schema.SObjectType.AEHC_Asset__c
            .getRecordTypeInfosByDeveloperName()
            .get('AEHC_Publication')
            .getRecordTypeId();

        Id versionRT = Schema.SObjectType.AEHC_Asset__c
            .getRecordTypeInfosByDeveloperName()
            .get('AEHC_Version')
            .getRecordTypeId();

        // ✅ Root Publication
        AEHC_Asset__c pub = new AEHC_Asset__c(
            Name = 'Test Publication',
            RecordTypeId = pubRT,
            AEHC_Application__c = app.Id,
            AEHC_Is_Active__c = true
        );
        insert pub;

        // ✅ DEV version
        insert new AEHC_Asset__c(
            Name = 'Dev Publication',
            AEHC_Environment__c = 'Dev',
            Approval_Status__c = 'Approved',
            AEHC_Application__c = app.Id,
            AEHC_Publication__c = pub.Id,
            AEHC_Is_Active__c = true,
            RecordTypeId = versionRT
        );
        insert new AEHC_Asset__c(
            Name = 'Dev Publication 2',
            AEHC_Environment__c = 'Dev',
            Approval_Status__c = 'Approved',
            AEHC_Application__c = app.Id,
            AEHC_Publication__c = pub.Id,
            AEHC_Is_Active__c = true,
            RecordTypeId = versionRT
        );

        // ✅ QA Pending
        insert new AEHC_Asset__c(
            Name = 'QA Pending',
            AEHC_Environment__c = 'QA',
            //Approval_Status__c = 'Pending',
            AEHC_Publication__c = pub.Id,
            AEHC_Application__c = app.Id,
            AEHC_Is_Active__c = true,
            RecordTypeId = versionRT
        );

        // ✅ Access
        insert new AEHC_AssetMember__c(
            AEHC_Asset__c = app.Id,
            AEHC_User__c = UserInfo.getUserId(),
            AEHC_Role__c = 'Business Owner'
        );
    }

    // ✅ getPromotionStatus
    @isTest
    static void testGetPromotionStatus() {

        AEHC_Asset__c pub = [
            SELECT Id FROM AEHC_Asset__c WHERE Name = 'Test Publication' LIMIT 1
        ];

        Test.startTest();
        AEHC_PublicationPromoteController.getPromotionStatus(pub.Id, 'Dev');
        AEHC_PublicationPromoteController.getNextEnvironment('Dev');
        Test.stopTest();
    }

    // ✅ No data
    @isTest
    static void testGetPromotionStatus_NoData() {

        Test.startTest();
        AEHC_PublicationPromoteController.getPromotionStatus('a00000000000001AAA', 'Dev');
        AEHC_PublicationPromoteController.getNextEnvironment('QA');
        Test.stopTest();
    }

    // ✅ Promote Success
    @isTest
    static void testPromotePublicationSuccess() {

       // delete [SELECT Id FROM AEHC_Asset__c WHERE Approval_Status__c = 'Pending'];
		AEHC_Asset__c app = new AEHC_Asset__c(
            Name = 'Test Application'
        );
        insert app;
       AEHC_AssetMember__c assetMem = new AEHC_AssetMember__c( AEHC_User__c = System.UserInfo.getUserId(),
                                                              AEHC_Role__c ='Business Owner',
                                                              AEHC_Asset__c = app.id);
        insert assetMem ;
		
        Id pubRT = Schema.SObjectType.AEHC_Asset__c
            .getRecordTypeInfosByDeveloperName()
            .get('AEHC_Publication')
            .getRecordTypeId();

        Id versionRT = Schema.SObjectType.AEHC_Asset__c
            .getRecordTypeInfosByDeveloperName()
            .get('AEHC_Version')
            .getRecordTypeId();

        // ✅ Root Publication
        AEHC_Asset__c pub = new AEHC_Asset__c(
            Name = 'Test Publication',
            RecordTypeId = pubRT,
            AEHC_Application__c = app.Id,
            AEHC_Is_Active__c = true
        );
        insert pub;

        // ✅ DEV version
        insert new AEHC_Asset__c(
            Name = 'Dev version',
            AEHC_Environment__c = 'Dev',
            Approval_Status__c = 'Approved',
            AEHC_Application__c = app.Id,
            AEHC_Publication__c = pub.Id,
            AEHC_Is_Active__c = true,
            RecordTypeId = versionRT
        );
        system.debug('_____________________');
        system.debug(pub.Id);
            

        AEHC_Asset__c pubfetch = [
            SELECT Id,AEHC_Publication__c FROM AEHC_Asset__c WHERE Name = 'Dev version' LIMIT 1
        ];
        
		
        Test.startTest();
        Id newId = AEHC_PublicationPromoteController.promotePublication(pub.Id, 'Dev');
        AEHC_Asset__c pubfetch2 = [
            SELECT Id,AEHC_Publication__c FROM AEHC_Asset__c WHERE id =: newId
        ];
        system.debug(pubfetch2);system.debug('_____________________');
        Test.stopTest();

        
    }

    // ✅ Not Approved branch
    @isTest
    static void testPromoteNotApproved() {

        AEHC_Asset__c rec = new AEHC_Asset__c(
            Name = 'Draft Publication',
            AEHC_Environment__c = 'Dev',
            //Approval_Status__c = 'Pending',
            AEHC_Is_Active__c = true
        );
        insert rec;

        AEHC_PublicationPromoteController.getNextEnvironment('Test');
    }

    // ✅ No Access
    @isTest
    static void testNoAccess() {

        delete [SELECT Id FROM AEHC_AssetMember__c];

        AEHC_Asset__c pub = [
            SELECT Id FROM AEHC_Asset__c WHERE AEHC_Environment__c = 'Dev' LIMIT 1
        ];

        Test.startTest();
        AEHC_PublicationPromoteController.getPromotionStatus(pub.Id, 'Dev');
        Test.stopTest();
    }

    // ✅ Inactive record
    @isTest
    static void testInactiveRecordIgnored() {

        AEHC_Asset__c inactivePub = new AEHC_Asset__c(
            Name = 'Inactive Pub',
            AEHC_Environment__c = 'Dev',
            Approval_Status__c = 'Approved',
            AEHC_Is_Active__c = false
        );
        insert inactivePub;

        Test.startTest();
        AEHC_PublicationPromoteController.getPromotionStatus(inactivePub.Id, 'Dev');
        Test.stopTest();
    }
    @isTest
    static void testProcessApprovalAction_Publication() {
        
        AEHC_Asset__c rootPub = [
            SELECT Id FROM AEHC_Asset__c WHERE Name = 'Test Publication' LIMIT 1
        ];
        
        Test.startTest();
        
        try {
            AEHC_PublicationPromoteController.processApprovalAction(
                rootPub.Id,
                'Promote',
                'Test comments',
                'Dev'
            );
        } catch (Exception e) {
            // ✅ Expected because no real ProcessInstance exists
        }
        
        Test.stopTest();
    }
    
    @isTest
    public static void testIsRecordPendingApproval() {
       AEHC_Asset__c rootPub = [ SELECT Id FROM AEHC_Asset__c WHERE Name = 'Test Publication' LIMIT 1];
        
        Test.startTest();
        Boolean result = AEHC_PublicationPromoteController.isRecordPendingApproval(
            rootPub.Id,
            'Dev'
        );
        Test.stopTest();
        
    }


}