/**
 * @author Asif Ahmad
 * @date 17Apr2026
 * @description Controller of LWC 
 * @app AEHC
*/
public with sharing class AEHC_SubscriptionControllerAO {

    /**
     * @author Asif Ahmad
     * @date 17Apr2026
     * @description to provide the subscription summary records in the context of current User:Asset owner  
     * @return to return result in form of Map with keys as status and data
	*/
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getSubscriptionSummary() {
        Map<String, Object> result = new Map<String, Object>();
        try {
            
            // get Asset Ids
            List<String> assetIds = new List<String>();
            for(AEHC_AssetMember__c amRec : [SELECT Id, AEHC_CommunityAsset__c FROM AEHC_AssetMember__c WHERE AEHC_User__c = :UserInfo.getUserId()]) 
                assetIds.add(amRec.AEHC_CommunityAsset__c);
            
            // counts all the subscriptions and griup by Asset Type
            Map<String, Integer> matrix = new Map<String, Integer>();
            
            for (AggregateResult ar : [
                SELECT AEHC_AssetType__c assetType, COUNT(Id) cnt
                FROM Subscription__c WHERE Community_Asset__c IN :assetIds AND Status__c = :AEHC_Constant.ACTIVE
                GROUP BY AEHC_AssetType__c
            ]) {
                String assetType = (String)ar.get('assetType');
                if(String.isEmpty(assetType)) assetType = 'Others';
                matrix.put(assetType, (Integer)ar.get('cnt'));
            }

            result.put('status', 200);
            result.put('data', matrix);
            
        } catch(Exception e) {
            AEHC_Logger.logException(e, 'Apex', 'AEHC_SubscriptionControllerAO', 'other', null, 'P1', null, null, 'Dev');
            result.put('status', 500);
            result.put('message', e.getMessage());
        }
        return result;
    }

}