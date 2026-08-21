public class AEHC_GroupCreationOnAssetHandler {

    public static void accountCreation(List<AEHC_Asset__c> newList){
        if(newList == null || newList.isEmpty()) {
            return;
        }

        Id appRtId = AEHC_Utility.getRecordTypeId( 'AEHC_Asset__c', AEHC_Constant.RECORDTYPENAME_ASSET_APPLICATION  );

        Set<String> appNames = new Set<String>();

        for(AEHC_Asset__c asset : newList){
            if(asset.RecordTypeId == appRtId){ appNames.add(asset.Name); }
        }

        if(appNames.isEmpty()){
            return;
        }

        Map<String, Id> accountMap = new Map<String, Id>();

        for(Account acc :  [SELECT Id, Name  FROM Account  WHERE Name IN :appNames]){
            accountMap.put(acc.Name, acc.Id);
        }

        List<AEHC_Asset__c> assetUpdates = new List<AEHC_Asset__c>();
        List<AEHC_AccountCreationRequest__e> events = new List<AEHC_AccountCreationRequest__e>();

        for(AEHC_Asset__c asset : newList){

            if(asset.RecordTypeId != appRtId){
                continue;
            }

            if(accountMap.containsKey(asset.Name)){
                assetUpdates.add( new AEHC_Asset__c( Id = asset.Id,  AEHC_Account__c = accountMap.get(asset.Name) ) );

            } else {
                events.add(
                    new AEHC_AccountCreationRequest__e(
                        AEHC_AssetId__c = asset.Id,
                        AEHC_Asset_Name__c = asset.Name,
                        AEHCApplicationId__c=asset.AEHC_Application_Id__c,
                        AEHC_SObjectType__c='Asset'
                    )
                );
            }
        } 

        if(!assetUpdates.isEmpty()){
            update assetUpdates;
        }

        if(!events.isEmpty()){
            EventBus.publish(events);
        }
    }
}