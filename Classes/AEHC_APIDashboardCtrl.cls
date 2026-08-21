/**
 * @author Asif Ahmad
 * @date 17Apr2026
 * @description Controller of LWC 
 * @app AEHC
*/
public with sharing class AEHC_APIDashboardCtrl {
    
    /**
     * @author Asif Ahmad
     * @date 17Apr2026
     * @description to provide the APIs counts with types in form of matrix  
     * @return to return result in form of Map with keys as status and data
	*/
    @AuraEnabled(Cacheable=true)
    public static Map<String, Object> getPublishedAPIMatrix() {
        
        Map<String, Object> result = new Map<String, Object>();
        try {
            
            // get current User Group Names, it belongs
            String currUserId = UserInfo.getUserId();
            List<String> groupNames = new List<String>();
            for(AEHC_AssetMember__c amRec : [SELECT Id, AEHC_CommunityAsset__r.AEHC_APIAssetOwner__c FROM AEHC_AssetMember__c WHERE AEHC_User__c =:currUserId AND AEHC_CommunityAsset__r.AEHC_APIAssetOwner__c != null]) {
                groupNames.add(amRec.AEHC_CommunityAsset__r.AEHC_APIAssetOwner__c);
            }
            
            // get APIs details array from the Mulesoft
            List<Object> assets = AEHC_Mule_GetAPIService.getAPIs();
            
            Map<String, Integer> apiMatrix = new Map<String, Integer>();
            
            // iterate over list of assets and collect only current user group Names
            for(Object assetItem : assets) {
                Map<String, Object> assetItemMap = (Map<String, Object>)assetItem;
                
                String contactName = AEHC_Utility.getStringFromMap(assetItemMap, 'contactName', null);
                
                if(groupNames.contains(contactName)) {
                    String assetType = AEHC_Utility.getStringFromMap(assetItemMap, 'type', null);
                    
                    if(String.isEmpty(assetType)) assetType = 'Others';
                    
                    if(!apiMatrix.containsKey(assetType)) apiMatrix.put(assetType, 1);
                    else apiMatrix.put(assetType, apiMatrix.get(assetType) + 1);
                }
            }
            
            result.put('status', 200);
            result.put('data', apiMatrix);
            
        } catch(Exception e) {
            AEHC_Logger.logException(e, 'Apex', 'AEHC_APIDashboardCtrl', 'other', null, 'P1', 'Integration', null, 'Dev');
            result.put('status', 500);
            result.put('message', e.getMessage());
        }
        return result;
    }
}