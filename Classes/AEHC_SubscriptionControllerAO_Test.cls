@IsTest
public class AEHC_SubscriptionControllerAO_Test {

   final static String TestUsername = 'johndoe.test@kpmg.test12345';

    @TestSetup
    static void setupData() {

        // Create Portal User
        final User portalUser = AEHC_TestDataFactory.create_ExternalUser(TestUsername);
        
        String assetOwnerName = 'HTTP-GROUP';
        
        AEHC_TestDataFactory.assignPermissionSet(portalUser.Id, new List<String>{'MemberUser', 'AEHC_Asset_Owner_PS'});
        
        ms_aeh__CommunityAsset__c assetRec = AEHC_TestDataFactory.create_CommunityAsset('graph', true);
        AEHC_Utility.addUserInAsset(assetRec.Id, portalUser.Id, AEHC_Constant.ASSET_OWNER, true);

        final List<Subscription__c> subs = new List<Subscription__c>{
            new Subscription__c(
                Community_Asset__c = assetRec.Id,
                AEHC_AssetType__c = 'API_A',
                Status__c = AEHC_Constant.ACTIVE
            ),
            new Subscription__c(
                Community_Asset__c = assetRec.Id,
                AEHC_AssetType__c = 'API_A'
            )
        };
        insert subs;
        
        subs[0].Status__c = AEHC_Constant.ACTIVE;
        subs[1].Status__c = AEHC_Constant.ACTIVE;
        update subs;
       
    }

    @IsTest
    static void testGetSubscriptionSummary() {

        User testUser = [SELECT Id FROM User WHERE Username = :TestUsername];
        
        Map<String, Object> result;
        System.runAs(testUser) {
            Test.startTest();
            result = AEHC_SubscriptionControllerAO.getSubscriptionSummary();
            Test.stopTest();
            
        }
        
        Map<String, Integer> dataMatrix = new Map<String, Integer>(); 
        if(Integer.valueOf(result.get('status')) == 200) {
            dataMatrix = (Map<String, Integer>)result.get('data');
        }
        // Validate map contains expected keys
        
    }
}