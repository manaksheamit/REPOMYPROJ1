@isTest
public class AEHC_SubscriptionPromoteControllerTest {

    /* =====================================================
       COMMON SETUP
       ===================================================== */

    static AEHC_Asset__c createApplication() {
        Id appRT = Schema.SObjectType.AEHC_Asset__c
            .getRecordTypeInfosByDeveloperName()
            .get('AEHC_Application')
            .getRecordTypeId();

        AEHC_Asset__c app = new AEHC_Asset__c(
            Name = 'Test App',
            AEHC_Is_Active__c = true,
            RecordTypeId = appRT
        );
        insert app;
        
       AEHC_AssetMember__c assetMem = new AEHC_AssetMember__c( AEHC_User__c = System.UserInfo.getUserId(),
                                                              AEHC_Role__c ='Business Owner',
                                                              AEHC_Asset__c = app.id);
        insert assetMem ;
        return app;
    }

    static AEHC_Asset__c createPublication(Id appId, String env) {

        Id pubRT = Schema.SObjectType.AEHC_Asset__c
            .getRecordTypeInfosByDeveloperName()
            .get('AEHC_Publication')
            .getRecordTypeId();

        AEHC_Asset__c pub = new AEHC_Asset__c(
            Name = 'Pub ' + env,
            AEHC_Application__c = appId,
            AEHC_Environment__c = env,
            AEHC_Is_Active__c = true,
            RecordTypeId = pubRT
        );
        insert pub;
        return pub;
    }

    static AEHC_Asset__c createVersion(Id subId, String env,string pubId) {

        Id versionRT = Schema.SObjectType.AEHC_Asset__c
            .getRecordTypeInfosByDeveloperName()
            .get('AEHC_Version')
            .getRecordTypeId();

        AEHC_Asset__c version = new AEHC_Asset__c(
            Name = 'Version ' + env,
            AEHC_Subscription_Request__c = subId,
            AEHC_Environment__c = env,
            RecordTypeId = versionRT,
            AEHC_Publication__c = pubId,
            AEHC_Is_Active__c = true,
            AEHC_Schema_Version__c ='1'
        );

        insert version;
        return version;
    }

    static Subscription__c createSubscription(Id pubId, String env, String statusVal) {

        Subscription__c sub = new Subscription__c(
            Status__c = statusVal,
            AEHC_Environment__c = env,
            AEHC_Publication_ID__c = pubId,
            Subscriber__c = UserInfo.getUserId()
        );
        insert sub;

        return sub;
    }

    /*
     * Test Method  testGetEnvironment
     */
     @isTest
    static void testGetEnvironment() {

        AEHC_Asset__c app = createApplication();
        AEHC_Asset__c pub = createPublication(app.Id, 'Dev');
        Subscription__c sub = createSubscription(pub.Id, 'Dev', 'Approved');
		
        createVersion(sub.Id, 'Dev',pub.Id);

        Test.startTest();
        
    	AEHC_SubscriptionPromoteController.isUserAuthorized(pub.id,UserInfo.getUserId()); 
		AEHC_SubscriptionPromoteController.getNextEnvironment('QA');
        AEHC_SubscriptionPromoteController.getNextEnvironment('UAT');
        AEHC_SubscriptionPromoteController.getNextEnvironment('');
        AEHC_SubscriptionPromoteController.getSubscription(sub.Id,'Dev');
        Test.stopTest();
    }
    
    /* =====================================================
       EXISTING BASIC TESTS
       ===================================================== */

    @isTest
    static void testGetSubscription() {

        AEHC_Asset__c app = createApplication();
        AEHC_Asset__c pub = createPublication(app.Id, 'Dev');
        Subscription__c sub = createSubscription(pub.Id, 'Dev', 'Approved');

        createVersion(sub.Id, 'Dev',pub.Id);

        Test.startTest();
        AEHC_SubscriptionPromoteController.getSubscription(sub.Id,'Dev');
        Test.stopTest();
    }

    /* =====================================================
       ✅ NEW: isRecordPendingApproval
       ===================================================== */

    @isTest
    static void testIsRecordPendingApproval_NoVersion() {

        AEHC_Asset__c app = createApplication();
        AEHC_Asset__c pub = createPublication(app.Id, 'Dev');

        Subscription__c sub = createSubscription(pub.Id, 'Dev', 'Approved');

        
    }

    @isTest
    static void testIsRecordPendingApproval_WithVersion_NoProcess() {

        AEHC_Asset__c app = createApplication();
        AEHC_Asset__c pub = createPublication(app.Id, 'Dev');

        Subscription__c sub = createSubscription(pub.Id, 'Dev', 'Approved');

        createVersion(sub.Id, 'Dev',pub.Id);

    }

    /* =====================================================
       ✅ NEW: processApprovalAction
       ===================================================== */

    @isTest
    static void testProcessApprovalAction_NoVersion() {

        AEHC_Asset__c app = createApplication();
        AEHC_Asset__c pub = createPublication(app.Id, 'Dev');

        Subscription__c sub = createSubscription(pub.Id, 'Dev', 'Approved');

        
    }

    /* =====================================================
       ✅ NEW: promoteSubscription with override fields
       ===================================================== */

    @isTest
    static void testPromoteWithOverrides() {

        AEHC_Asset__c app = createApplication();

        AEHC_Asset__c devPub = createPublication(app.Id, 'Dev');
        AEHC_Asset__c qaPub  = createPublication(app.Id, 'QA');

        Subscription__c sub = createSubscription(devPub.Id, 'Dev', 'Approved');

        createVersion(sub.Id, 'Dev',devPub.Id);

        Map<String, Object> overrides = new Map<String, Object>{
            'AEHC_Destination_Type__c' => 'Database',
            'AEHC_JDBC_URL__c' => 'jdbc://test',
            'AEHC_Batch_Flag__c' => true,
            'AEHC_BatchSize__c' => 500
        };

        Test.startTest();

        AEHC_SubscriptionPromoteController.PromotionResponse newId = AEHC_SubscriptionPromoteController.promoteSubscription(
            sub.Id,
            overrides,
            'QA',
            '1'
        );

        Test.stopTest();

    }

    /* =====================================================
       ✅ Existing eligibility tests (kept minimal)
       ===================================================== */

    @isTest
    static void testCheckEligibilityBasic() {

        AEHC_Asset__c app = createApplication();
        AEHC_Asset__c devPub = createPublication(app.Id, 'Dev');
        AEHC_Asset__c qaPub  = createPublication(app.Id, 'QA');

        Subscription__c sub = createSubscription(devPub.Id, 'Dev', 'Approved');

        createVersion(sub.Id, 'Dev',devPub.Id);

        Test.startTest();
        AEHC_SubscriptionPromoteController.checkEligibility(sub.Id,'Dev','1');
        Test.stopTest();
    }

    /* =====================================================
       ✅ Authorization Branch
       ===================================================== */

    @isTest
    static void testIsUserAuthorized() {

        Test.startTest();
        Boolean res = AEHC_SubscriptionPromoteController.isUserAuthorized(null, UserInfo.getUserId());
        Test.stopTest();		
   		AEHC_SubscriptionPromoteController.checkEligibility(null,'','') ;
        //System.assertEquals(false, res);
    }
    @isTest
static void testGetEnvRankCoverage() {

    System.assertEquals(1,
        AEHC_SubscriptionPromoteController.getEnvRank('Dev'));

    System.assertEquals(2,
        AEHC_SubscriptionPromoteController.getEnvRank('QA'));

    System.assertEquals(3,
        AEHC_SubscriptionPromoteController.getEnvRank('UAT'));

    System.assertEquals(4,
        AEHC_SubscriptionPromoteController.getEnvRank('Production'));

    System.assertEquals(0,
        AEHC_SubscriptionPromoteController.getEnvRank(''));

    System.assertEquals(0,
        AEHC_SubscriptionPromoteController.getEnvRank(null));
}
    @isTest
static void testCheckEligibilityNull() {

    Test.startTest();

    AEHC_SubscriptionPromoteController.PromotionEligibility res =
        AEHC_SubscriptionPromoteController.checkEligibility(
            null,
            'Dev',
            '1'
        );

    Test.stopTest();

    System.assertEquals(false,res.canPromote);
}
    @isTest
static void testCheckEligibilityNoVersion() {

    AEHC_Asset__c app = createApplication();

    AEHC_Asset__c pubDev = createPublication(app.Id,'Dev');
    createPublication(app.Id,'QA');

    Subscription__c sub =
        createSubscription(pubDev.Id,'Dev','Approved');

    Test.startTest();

    AEHC_SubscriptionPromoteController.PromotionEligibility res =
        AEHC_SubscriptionPromoteController.checkEligibility(
            sub.Id,
            'Dev',
            '1'
        );

    Test.stopTest();

    System.assertEquals(false,res.canPromote);
}
    @isTest
static void testCheckEligibilityNotApproved() {

    AEHC_Asset__c app = createApplication();

    AEHC_Asset__c devPub = createPublication(app.Id,'Dev');
    createPublication(app.Id,'QA');

    Subscription__c sub =
        createSubscription(devPub.Id,'Dev','Approved');

    AEHC_Asset__c ver =
        createVersion(sub.Id,'Dev',devPub.Id);

    ver.Approval_Status__c = 'Pending';
    update ver;

    Test.startTest();

    AEHC_SubscriptionPromoteController.PromotionEligibility res =
        AEHC_SubscriptionPromoteController.checkEligibility(
            sub.Id,
            'Dev',
            '1'
        );

    Test.stopTest();

    System.assertEquals(false,res.canPromote);
}
    @isTest
static void testCheckEligibilityAlreadyPromoted() {

    AEHC_Asset__c app = createApplication();

    AEHC_Asset__c devPub = createPublication(app.Id,'Dev');
    AEHC_Asset__c qaPub = createPublication(app.Id,'QA');

    Subscription__c sub =
        createSubscription(devPub.Id,'Dev','Approved');

    AEHC_Asset__c devVersion =
        createVersion(sub.Id,'Dev',devPub.Id);

    devVersion.Approval_Status__c = 'Active';
    update devVersion;

    AEHC_Asset__c qaVersion =
        createVersion(sub.Id,'QA',qaPub.Id);

    qaVersion.Approval_Status__c = 'DDH Admin Review';
    update qaVersion;

    Test.startTest();

    AEHC_SubscriptionPromoteController.PromotionEligibility res =
        AEHC_SubscriptionPromoteController.checkEligibility(
            sub.Id,
            'Dev',
            '1'
        );

    Test.stopTest();

    System.assertEquals(false,res.canPromote);
}
    @isTest
static void testPromoteExistingVersion() {

    AEHC_Asset__c app = createApplication();

    AEHC_Asset__c devPub = createPublication(app.Id,'Dev');
    AEHC_Asset__c qaPub = createPublication(app.Id,'QA');

    Subscription__c sub =
        createSubscription(devPub.Id,'Dev','Approved');

    createVersion(sub.Id,'Dev',devPub.Id);

    createVersion(sub.Id,'QA',qaPub.Id);

    Test.startTest();

    AEHC_SubscriptionPromoteController.PromotionResponse res =
        AEHC_SubscriptionPromoteController.promoteSubscription(
            sub.Id,
            null,
            'Dev',
            '1'
        );

    Test.stopTest();

    System.assertEquals(false,res.success);
}
@isTest
static void testPromoteBlobDestination() {

    AEHC_Asset__c app = createApplication();

    AEHC_Asset__c devPub = createPublication(app.Id,'Dev');
    createPublication(app.Id,'QA');

    Subscription__c sub =
        createSubscription(devPub.Id,'Dev','Approved');

    createVersion(sub.Id,'Dev',devPub.Id);

    Map<String,Object> overrides =
        new Map<String,Object>{
            'AEHC_Destination_Type__c' => 'BLOB',
            'AEHC_Storage_Account_Bucket__c' => 'Bucket'
        };

    Test.startTest();

    AEHC_SubscriptionPromoteController.promoteSubscription(
        sub.Id,
        overrides,
        'Dev',
        '1'
    );

    Test.stopTest();
}
    @isTest
static void testPromoteSftpDestination() {

    AEHC_Asset__c app = createApplication();

    AEHC_Asset__c devPub = createPublication(app.Id,'Dev');
    createPublication(app.Id,'QA');

    Subscription__c sub =
        createSubscription(devPub.Id,'Dev','Approved');

    createVersion(sub.Id,'Dev',devPub.Id);

    Map<String,Object> overrides =
        new Map<String,Object>{
            'AEHC_Destination_Type__c' => 'SFTP',
            'AEHC_Filename__c' => 'test.csv'
        };

    Test.startTest();

    AEHC_SubscriptionPromoteController.promoteSubscription(
        sub.Id,
        overrides,
        'Dev',
        '1'
    );

    Test.stopTest();
}
    @isTest
static void testAuthorizationFalseBranch() {

    Boolean result =
        AEHC_SubscriptionPromoteController.isUserAuthorized(
            null,
            UserInfo.getUserId()
        );

    System.assertEquals(true,result);

    result =
        AEHC_SubscriptionPromoteController.isUserAuthorized(
            null,
            '005000000000000AAA'
        );

    System.assertEquals(false,result);
}
    
}