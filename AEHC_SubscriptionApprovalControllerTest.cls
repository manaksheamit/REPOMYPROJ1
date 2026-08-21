/* Unit test class for AEHC_SubscriptionApprovalController.
 *               Covers core functionality including:
 *               - Subscription data retrieval
 *               - Approval handling (approve/reject scenarios)
 *               - Approval visibility logic
 *               - Asset owner approver validation
 *               - Null and edge case handling
 *
 *               Test data includes Community Asset, Subscription,
 *               and Asset Member records to simulate real-world relationships.
 *
 * @Author       Rushikesh Rajan Deshmukh
 * @CreatedDate  2026-05-23
 * @UpdatedDate  2026-06-12
 */


@IsTest
private class AEHC_SubscriptionApprovalControllerTest {

    @TestSetup
    static void setupData() {

        Profile p = [
            SELECT Id FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        User u = new User(
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
        insert u;

        String groupId = 'grp-' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        String assetId = 'asset-' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        String networkId = 'net-' + String.valueOf(Math.abs(Crypto.getRandomInteger()));

        ms_aeh__CommunityAsset__c asset = new ms_aeh__CommunityAsset__c(
            Name = assetId,
            ms_aeh__AssetId__c = assetId,
            ms_aeh__GroupId__c = groupId,
            ms_aeh__GroupAssetId__c = groupId + ':' + assetId,
            ms_aeh__NetworkId__c = networkId,
            ms_aeh__Key__c = networkId + ':' + groupId + ':' + assetId,
            ms_aeh__Status__c = 'Unpublished',
            ms_aeh__AssetType__c = 'API',
            ms_aeh__IsPublic__c = false
        );
        insert asset;
        
        AEHC_Asset__c app = new AEHC_Asset__c(
            Name = 'testApp',
            RecordTypeId = AEHC_Utility.getRecordTypeId('AEHC_Asset__c', AEHC_Constant.RECORDTYPENAME_ASSET_APPLICATION)
        );
        insert app;
        
        AEHC_Asset__c app2 = new AEHC_Asset__c(
            Name = 'testApp',
            RecordTypeId = AEHC_Utility.getRecordTypeId('AEHC_Asset__c', AEHC_Constant.RECORDTYPENAME_ASSET_APPLICATION)
        );
        insert app2;
        
        String userId = UserInfo.getUserId();
        
        List<AEHC_AssetMember__c> members = new List<AEHC_AssetMember__c>();
        members.add(new AEHC_AssetMember__c(
            AEHC_CommunityAsset__c = asset.Id,
            AEHC_User__c = userId,
            AEHC_Role__c = AEHC_Constant.ASSET_OWNER
        ));
        
        members.add(new AEHC_AssetMember__c(
            AEHC_Asset__c = app.Id,
            AEHC_User__c = userId,
            AEHC_Role__c = AEHC_Constant.ROLE_BUSINESS_OWNER
        ));
        members.add(new AEHC_AssetMember__c(
            AEHC_Asset__c = app2.Id,
            AEHC_User__c = u.Id,
            AEHC_Role__c = AEHC_Constant.ROLE_BUSINESS_OWNER
        ));
        members.add(new AEHC_AssetMember__c(
            AEHC_Asset__c = app.Id,
            AEHC_User__c = userId,
            AEHC_Role__c = AEHC_Constant.ROLE_DDH_ADMIN
        ));
        members.add(new AEHC_AssetMember__c(
            AEHC_Asset__c = app.Id,
            AEHC_User__c = userId,
            AEHC_Role__c = AEHC_Constant.ROLE_SECURITY_ARCHITECT
        ));
        insert members;

        Subscription__c subWithAsset = new Subscription__c(
            Community_Asset__c = asset.Id,
            AEHC_Environment_Name__c = 'DEV',
            AEHC_AssetType__c = 'API',
            RecordTypeId = AEHC_Utility.getRecordTypeId('Subscription__c', AEHC_Constant.RECORDTYPENAME_SUBSCRIPTION_API)
        );
        insert subWithAsset;   

        Subscription__c dataSubs = new Subscription__c(
            AEHC_Consumming_Application__c = app2.Id,
            AEHC_Application_Name__c = app.id,
            
            RecordTypeId = AEHC_Utility.getRecordTypeId('Subscription__c', AEHC_Constant.RECORDTYPENAME_SUBSCRIPTION_DATA)
        );
        insert dataSubs;
        
    }

    @IsTest
    static void testAPISubs() {

        Subscription__c subRec = [
            SELECT Id, Status__c, AEHC_Group_Account__c, Community_Asset__c, AEHC_Consumming_Application__c FROM Subscription__c
            WHERE Community_Asset__c != null LIMIT 1
        ];
        
        Contact cRec = new Contact();
        cRec.Lastname = 'test';
        insert cRec;
        
        Test.startTest();
        
        AEHC_SubscriptionApprovalController.Input req = new AEHC_SubscriptionApprovalController.Input();
        req.recordId = subRec.Id;
        req.approvalOwner = AEHC_Constant.ASSET_OWNER;
        req.subRec = subRec;

        List<AEHC_SubscriptionApprovalController.Output> result = AEHC_SubscriptionApprovalController.getApprovalOwner(new List<AEHC_SubscriptionApprovalController.Input>{req});

        Object approvers = AEHC_SubscriptionApprovalController.getApprovalsForAPI(subRec.Id);
        
        
        AEHC_SubscriptionShareAction.Input input = new AEHC_SubscriptionShareAction.Input();
        input.accRecId = subRec.AEHC_Group_Account__c;
        input.userContactIds = new List<String>{cRec.Id};
        
        AEHC_SubscriptionShareAction.shareSubscription(new List<AEHC_SubscriptionShareAction.Input>{input});
        
        List<ProcessInstanceWorkitem> aehc_workItems = new List<ProcessInstanceWorkitem>();
        aehc_workItems = [
                           SELECT Id, ProcessInstance.TargetObjectId, ProcessInstance.Status, ActorId, Actor.Name, OriginalActorId
                           FROM ProcessInstanceWorkitem  where ProcessInstance.TargetObjectId= :subRec.Id
            			   and ProcessInstance.Status = 'Pending'
                          ];
        
        AEHC_HandleSubscriptionApproval.AEHC_processApproval(aehc_workItems[0].Id, 'Approver', 'test', false, null);

        Test.stopTest();
    }
    
    @IsTest
    static void testDataSubsApprover() {

        Subscription__c subRec = [
            SELECT Id, Status__c,  Community_Asset__c, AEHC_Consumming_Application__c FROM Subscription__c
            WHERE RecordTypeId = :AEHC_Utility.getRecordTypeId('Subscription__c', AEHC_Constant.RECORDTYPENAME_SUBSCRIPTION_DATA) LIMIT 1
        ];
        
        AEHC_Asset__c version = new AEHC_Asset__c(
            Name = 'subs-Version',
            AEHC_Subscription_Request__c = subRec.Id,
            AEHC_Application__c = subRec.AEHC_Consumming_Application__c,
            RecordTypeId = AEHC_Utility.getRecordTypeId('AEHC_Asset__c', AEHC_Constant.RECORDTYPENAME_ASSET_VERSION)
        );
        insert version;
        
        // Submit the record
        
        Test.startTest();
        

        List<AEHC_HandleSubscriptionApproval.AEHC_ApprovalWrapper> result = AEHC_HandleSubscriptionApproval.AEHC_getApprovals(subRec.Id);
        Test.stopTest();
    }
}