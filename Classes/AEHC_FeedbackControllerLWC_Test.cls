/**
 * @author Asif Ahmad
 * @date 17Apr2026
 * @description Test Class for AEHC_FeedbackControllerLWC
 * @app AEHC
*/
@IsTest
public class AEHC_FeedbackControllerLWC_Test {
    
    final static String TestUsername = 'johndoe.test@kpmg.test12345';

    @TestSetup
    static void setupData() {

        // Create Portal User
        final User portalUser = AEHC_TestDataFactory.create_ExternalUser(TestUsername);
        
        // Setup Asset Record
        ms_aeh__CommunityAsset__c asset = AEHC_TestDataFactory.create_CommunityAsset('rest-api', true);
        AEHC_Utility.addUserInAsset(asset.Id, portalUser.Id, AEHC_Constant.ASSET_OWNER, true);

        // new FEED ITEMS (posts)
        List<FeedItem> feedItems = new List<FeedItem>();

        // Recent posts (should be counted)
        feedItems.add(new FeedItem(
            Body = 'Recent Post 1',
            ParentId = asset.Id,
            Type = 'TextPost'
        ));
        feedItems.add(new FeedItem(
            Body = 'Recent Post 2',
            ParentId = asset.Id,
            Type = 'TextPost'
        ));

        insert feedItems;

        // Old post (should NOT be counted)
        FeedItem oldPost = new FeedItem(
            Body = 'Old Post',
            ParentId = asset.Id,
            Type = 'TextPost'
        );
        insert oldPost;

        // Change created date outside LAST_N_DAYS:7
        Test.setCreatedDate(oldPost.Id, System.today().addDays(-20));
    }

    @IsTest
    static void testGetLastWeekFeedbackCount() {
        
        User testUser = [SELECT Id FROM User WHERE Username = :TestUsername];
        Map<String, Object> result;
        System.runAs(testUser) {
            
            Test.startTest();
            result = AEHC_FeedbackControllerLWC.getLastWeekFeedbackCount();
            Test.stopTest();
        }

        Integer count = Integer.valueOf(result.get('data'));
        
        System.assertEquals(
            2,
            count,
            'Expected 2 recent posts.'
        );
    }
}