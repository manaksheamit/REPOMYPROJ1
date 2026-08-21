public class AEHC_AccountCreationPEHandler {

    public static void process(List < AEHC_AccountCreationRequest__e > events) {

        if (events == null || events.isEmpty()) {
            return;
        }

        /*
         * Build a map of composite key -> Platform Event
         */
        Map < String, AEHC_AccountCreationRequest__e > eventMap = new Map < String, AEHC_AccountCreationRequest__e > ();
        Set < String > accountNames = new Set < String > ();
        Set < String > applicationIds = new Set < String > ();

        for (AEHC_AccountCreationRequest__e evt: events) {

            if (String.isBlank(evt.AEHC_Asset_Name__c) ||  String.isBlank(evt.AEHC_SObjectType__c)) {
                continue;
            }

            String key = buildKey(evt.AEHC_Asset_Name__c, evt.AEHCApplicationId__c);

            eventMap.put(key, evt);
            accountNames.add(evt.AEHC_Asset_Name__c);
            applicationIds.add(evt.AEHCApplicationId__c);
        }

        /*
         * Query existing Accounts
         */
        Map < String, Account > existingAccounts = new Map < String, Account > ();

        for (Account acc: [SELECT Id, Name, Application_Id__c FROM Account WHERE Name IN: accountNames AND Application_Id__c IN: applicationIds]) {

            existingAccounts.put(buildKey(acc.Name, acc.Application_Id__c), acc);
        }

        /*
         * Create missing Accounts
         */
        List < Account > accountsToInsert = new List < Account > ();
        List < String > insertKeys = new List < String > ();

        for (String key: eventMap.keySet()) {

            if (!existingAccounts.containsKey(key)) {
                AEHC_AccountCreationRequest__e evt = eventMap.get(key);
                accountsToInsert.add(new Account(Name = evt.AEHC_Asset_Name__c, Application_Id__c = evt.AEHCApplicationId__c));
                insertKeys.add(key);
            }
        }

        if (!accountsToInsert.isEmpty()) {

            List < Database.SaveResult > insertResults = Database.insert(accountsToInsert, false);

            for (Integer i = 0; i < insertResults.size(); i++) {

                if (insertResults[i].isSuccess()) {

                    existingAccounts.put(insertKeys[i], accountsToInsert[i]);

                } else {

                    List < String > errorArr = new List < String > ();

                    for (Database.Error err: insertResults[i].getErrors()) {
                        errorArr.add(err.getMessage());
                    }

                    AEHC_Logger.logError(String.join(errorArr, ';'), 'Apex', 'AEHC_AccountCreationPEHandler.process', 'Create', null, 'P3', 'DML',
                        new Map < String, Object > {
                            'recordIndex' => i,
                            'rec' => accountsToInsert[i]
                        }, AEHC_Utility.getCurrentEnvironment());
                }
            }
        }

        // Re-query Accounts after insert to ensure we use committed records

        Map < String, Id > accountIdMap = new Map < String, Id > ();

        for (Account acc: [SELECT Id, Name, Application_Id__c FROM Account WHERE Name IN: accountNames AND Application_Id__c IN: applicationIds]) {
            accountIdMap.put(buildKey(acc.Name, acc.Application_Id__c), acc.Id);
        }

        /*
         * Build Asset updates
         */
        List < AEHC_Asset__c > assetsToUpdate = new List < AEHC_Asset__c > ();
        List<ms_aeh__CommunityAsset__c> apisToUpdate= new List<ms_aeh__CommunityAsset__c>();

        for (AEHC_AccountCreationRequest__e evt: events) {

            if (String.isBlank(evt.AEHC_Asset_Name__c) || String.isBlank(evt.AEHC_AssetId__c) ) {
                continue;
            }

            String key = buildKey(evt.AEHC_Asset_Name__c, evt.AEHCApplicationId__c);

            Id accountId = accountIdMap.get(key);

            if (accountId != null && evt.AEHC_SObjectType__c== 'Asset') {
                assetsToUpdate.add(new AEHC_Asset__c(Id = evt.AEHC_AssetId__c, AEHC_Account__c = accountId));
            }
            else if (accountId != null && evt.AEHC_SObjectType__c== 'CommunityAsset'){
                apisToUpdate.add(new ms_aeh__CommunityAsset__c(Id = evt.AEHC_AssetId__c,AEHC_Account__c = accountId));
            }
        }

        /*
         * Update Assets
         */
        if (!assetsToUpdate.isEmpty()) {

            List < Database.SaveResult > updateResults =
                Database.update(assetsToUpdate, false);

            List < AEHC_Asset__c > retryAssets = new List < AEHC_Asset__c > ();

            for (Integer i = 0; i < updateResults.size(); i++) {

                if (!updateResults[i].isSuccess()) {
                    retryAssets.add(assetsToUpdate[i]);
                }
            }

            /*
             * Retry once
             */
            if (!retryAssets.isEmpty()) {
                System.enqueueJob(new AEHC_AssetUpdateQueueable(retryAssets));
            }
        }
        
        if (!apisToUpdate.isEmpty()) {

            List < Database.SaveResult > updateResults =  Database.update(apisToUpdate, false);

            List < ms_aeh__CommunityAsset__c > retryApis = new List < ms_aeh__CommunityAsset__c > ();

            for (Integer i = 0; i < updateResults.size(); i++) {

                if (!updateResults[i].isSuccess()) {
                    retryApis.add(apisToUpdate[i]);
                }
            }
        
            if (!retryApis.isEmpty()) {
                System.enqueueJob(new AEHC_AssetUpdateQueueable(retryApis));
            }
        }
    }


    private static String buildKey(String accountName, String applicationId) {
        return (accountName + '|' + applicationId);
    }
}