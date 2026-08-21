/**
 * @author Asif Ahmad
 * @date 17Apr2026
 * @description Test Class for AEHC_PendingSubscriptionsCtrlAO
 * @app AEHC
*/
@IsTest
public class AEHC_PendingSubscriptionsCtrlAO_Test {
    
    static User testUser;
    static Id appRT;
    
    @TestSetup
    static void setupData() {
        
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        
        testUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@test.com',
            Username = 'testuser' + System.currentTimeMillis() + '@test.com',
            Alias = 'tusr',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert testUser;
        
        appRT = Schema.SObjectType.AEHC_Asset__c
            .getRecordTypeInfosByDeveloperName()
            .get('AEHC_Application')
            .getRecordTypeId();
        
        AEHC_Asset__c asset = new AEHC_Asset__c(
            Name = 'Test Asset',
            RecordTypeId = appRT
        );
        insert asset;
        
        insert new AEHC_AssetMember__c(
            AEHC_Asset__c = asset.Id,
            AEHC_User__c = testUser.Id
        );
        
        insert new Subscription__c(
            Status__c = AEHC_Constant.SUBMITTED,
            AEHC_API_Asset_Owner__c = 'Owner1',
            AEHC_Environment_Name__c = 'PROD'
        );
        
        insert new Subscription__c(
            Status__c = AEHC_Constant.SUBMITTED
        );
    }
    
    //  getPendingSubscriptions SUCCESS
    @isTest
    static void testGetPendingSubscriptions_WithData() {
        User u = [SELECT Id FROM User WHERE Alias='tusr' LIMIT 1];
        
        Test.startTest();
        System.runAs(u) {
            Map<String, Object> result =
                AEHC_PendingSubscriptionsCtrlAO.getPendingSubscriptions();
            
        }
        Test.stopTest();
    }
    
    //  getPendingSubscriptions EMPTY → 404
    @isTest
    static void testGetPendingSubscriptions_NoData() {
        
        delete [SELECT Id FROM Subscription__c];
        
        Test.startTest();
        Map<String, Object> result =
            AEHC_PendingSubscriptionsCtrlAO.getPendingSubscriptions();
        Test.stopTest();
        
    }
    
    //  CreatedBy NULL + sort edge
    @isTest
    static void testCreatedByNullAndSort() {
        
        insert new Subscription__c(
            Status__c = 'Submitted',
            AEHC_Environment_Name__c = null
        );
        
        Test.startTest();
        AEHC_PendingSubscriptionsCtrlAO.getPendingSubscriptions();
        Test.stopTest();
        
    }
    
    //  continue (NO WORK ITEM PATH)
    @isTest
    static void testSkipNoWorkItemBranch() {
        
        insert new Subscription__c(
            Status__c = 'Submitted'
        );
        
        Test.startTest();
        List<AEHC_PendingSubscriptionsCtrlAO.SubscriptionWrapper> res =
            AEHC_PendingSubscriptionsCtrlAO.checkApprovalVisibility();
        Test.stopTest();
        
    }
    
    //  L1 APPROVAL PATH
    @isTest
    static void testCheckApprovalVisibility_L1() {
        
        User u = [SELECT Id FROM User WHERE Alias='tusr' LIMIT 1];
        AEHC_Asset__c asset = [SELECT Id FROM AEHC_Asset__c LIMIT 1];

	 	// Get RecordType
        RecordType rt = [SELECT Id FROM RecordType WHERE Developername =: label.AEHC_SubReq_DataPublication_RecType LIMIT 1];
        
        Subscription__c sub = new Subscription__c(
            Status__c = 'Submitted',
            Subscriber__c = u.Id,
            AEHC_L1_Approved__c = false,
            AHEC_L2_Approved__c = false,
            AEHC_Application_Name__c = asset.Id,
            AEHC_Environment_Name__c = 'UAT',
            RecordTypeId = rt.Id	
        );
        insert sub;
        
        Test.startTest();
        System.runAs(u) {
            AEHC_PendingSubscriptionsCtrlAO.checkApprovalVisibility();
        }
        Test.stopTest();
    }
    
    //  L2 APPROVAL PATH
    @isTest
    static void testCheckApprovalVisibility_L2() {
        
        User u = [SELECT Id FROM User WHERE Alias='tusr' LIMIT 1];
        AEHC_Asset__c asset = [SELECT Id FROM AEHC_Asset__c LIMIT 1];

 		// Get RecordType
        RecordType rt = [SELECT Id FROM RecordType WHERE Developername =: label.AEHC_SubReq_DataPublication_RecType LIMIT 1];
        
        Subscription__c sub = new Subscription__c(
            Status__c = 'Submitted',
            Subscriber__c = u.Id,
            AEHC_L1_Approved__c = true,
            AHEC_L2_Approved__c = false,
            AEHC_Application_Name__c = asset.Id,
            AEHC_Environment_Name__c = 'PROD',
            RecordTypeId = rt.Id
        );
        insert sub;
        
        Test.startTest();
        System.runAs(u) {
            AEHC_PendingSubscriptionsCtrlAO.checkApprovalVisibility();
        }
        Test.stopTest();
    }
    
    //  FILTER Approved/Rejected
    @isTest
    static void testApprovedFiltered() {
        
        insert new Subscription__c(
            Status__c = 'Approved'
        );
        
        Test.startTest();
        List<AEHC_PendingSubscriptionsCtrlAO.SubscriptionWrapper> res =
            AEHC_PendingSubscriptionsCtrlAO.checkApprovalVisibility();
        Test.stopTest();
        
    }
    
    //  EnvSort FULL branch coverage
    @isTest
    static void testEnvSort_AllCases() {
        
        AEHC_PendingSubscriptionsCtrlAO.EnvSort sorter =
            new AEHC_PendingSubscriptionsCtrlAO.EnvSort();
        
        AEHC_PendingSubscriptionsCtrlAO.SubscriptionWrapper prod =
            new AEHC_PendingSubscriptionsCtrlAO.SubscriptionWrapper();
        prod.Environment = 'PROD';
        
        AEHC_PendingSubscriptionsCtrlAO.SubscriptionWrapper uat =
            new AEHC_PendingSubscriptionsCtrlAO.SubscriptionWrapper();
        uat.Environment = 'UAT';
        
        AEHC_PendingSubscriptionsCtrlAO.SubscriptionWrapper other =
            new AEHC_PendingSubscriptionsCtrlAO.SubscriptionWrapper();
        other.Environment = 'DEV';
        
        AEHC_PendingSubscriptionsCtrlAO.SubscriptionWrapper blank =
            new AEHC_PendingSubscriptionsCtrlAO.SubscriptionWrapper();
        
        sorter.compare(prod, uat);
        sorter.compare(uat, other);
        sorter.compare(other, blank);
        
    }
    
    //  FINAL execution (covers remaining internal paths)
    @isTest
    static void testFullExecution() {
        
        Test.startTest();
        
        AEHC_PendingSubscriptionsCtrlAO.getPendingSubscriptions();
        AEHC_PendingSubscriptionsCtrlAO.checkApprovalVisibility();
        
        Test.stopTest();
    }
}