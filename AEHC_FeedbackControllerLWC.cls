/**
 * @author Asif Ahmad
 * @date 17Apr2026
 * @description Controller of LWC 
 * @app AEHC
*/
public without sharing class AEHC_FeedbackControllerLWC {

    /**
     * @author Asif Ahmad
     * @date 17Apr2026
     * @description to provide the Feedbacks received in the context of current User:Asset Owner  
     * @return to return result in form of Map with keys as status and data
	*/
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getLastWeekFeedbackCount() {
        Map<String, Object> result = new Map<String, Object>();
        
        // get Asset Ids
        List<String> assetIds = new List<String>();
        for(AEHC_AssetMember__c amRec : [SELECT Id, AEHC_CommunityAsset__c FROM AEHC_AssetMember__c WHERE AEHC_User__c = :UserInfo.getUserId()]) assetIds.add(amRec.AEHC_CommunityAsset__c);
        
        // Count all FeedItems from last 7 days
        Integer postCount = [
            SELECT COUNT()
            FROM FeedItem
            WHERE CreatedDate = LAST_N_DAYS:7
            AND Type != 'ContentPost'   // optional: exclude files if not feedback
            AND ParentId IN :assetIds
        ];
        
        result.put('status', 200);
        result.put('data', postCount);
        return result;
    }

}