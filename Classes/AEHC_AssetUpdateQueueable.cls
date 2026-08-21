public class AEHC_AssetUpdateQueueable implements Queueable {

    private List<AEHC_Asset__c> assets;
    private List<ms_aeh__CommunityAsset__c> apis;
    
    public AEHC_AssetUpdateQueueable(List<AEHC_Asset__c> assets){
        this.assets = assets;
    }
    public AEHC_AssetUpdateQueueable(List<ms_aeh__CommunityAsset__c> apis){
        this.apis = apis;
    }
    public void execute(QueueableContext qc){

        Database.SaveResult[] sr = Database.update(assets,false);
        for (Integer i = 0; i < sr.size(); i++) {

            if (!sr[i].isSuccess()) {
                List<String> errorArr = new List<String>();
                for (Database.Error err : sr[i].getErrors()) {
                    errorArr.add(err.getMessage());
                }

                AEHC_Logger.logError(String.join(errorArr, ';'), 'Apex','AEHC_AssetUpdateQueueable.execute','Create', null, 'P3','DML',
                    new Map<String, Object>{  'recordIndex' => i, 'rec' => assets[i] }, AEHC_Utility.getCurrentEnvironment());
            }
        }
    }
}