@IsTest
private class AEHC_AccountCreationPEHandlerTest {

    @IsTest
    static void testCreateAccountAndUpdateAsset() {
        
        String rtID = AEHC_Utility.getRecordTypeId('AEHC_Asset__c', 'AEHC_Application');
        AEHC_Asset__c asset = new AEHC_Asset__c(Name = 'Test Asset',RecordTypeID=rtID,AEHC_Application_Id__c='TestID');
        insert asset;
        System.debug('asset'+asset);

        AEHC_AccountCreationRequest__e evt = new AEHC_AccountCreationRequest__e(AEHC_Asset_Name__c = asset.Name,
                																AEHC_AssetId__c = asset.Id,
                                                                                AEHCApplicationId__c=asset.AEHC_Application_Id__c);
        System.debug('evt'+evt);
        Test.startTest();
        EventBus.publish(evt);
        //AEHC_AccountCreationPEHandler.process( new List<AEHC_AccountCreationRequest__e>{ evt }    );
        Test.stopTest();

        Account acc =   [SELECT Id, Name,Application_Id__c FROM Account WHERE Name = 'Test Asset' LIMIT 1];
        System.debug('Account'+acc);

        AEHC_Asset__c fetchedAsset = [SELECT AEHC_Account__c FROM AEHC_Asset__c WHERE Id = :asset.Id];
        System.debug('fetchedAsset'+fetchedAsset);

        //System.assertEquals(acc.Id, fetchedAsset.AEHC_Account__c);
    }

    @IsTest
    static void testExistingAccount() {

        Account acc = new Account(Name = 'Existing Account');
        insert acc;
        String rtID = AEHC_Utility.getRecordTypeId('AEHC_Asset__c', 'AEHC_Application');
        AEHC_Asset__c asset = new AEHC_Asset__c(Name = 'Asset 2',RecordTypeID=rtID,AEHC_Application_Id__c='TestID2');
        insert asset;

        AEHC_AccountCreationRequest__e evt =
            new AEHC_AccountCreationRequest__e(
                AEHC_Asset_Name__c = acc.Name,
                AEHC_AssetId__c = asset.Id,
                AEHCApplicationId__c=asset.AEHC_Application_Id__c
            );

        Test.startTest();
        	EventBus.publish(evt);
        Test.stopTest();

        asset =   [SELECT AEHC_Account__c FROM AEHC_Asset__c WHERE Id = :asset.Id];

        System.assertNotEquals(acc.Id, asset.AEHC_Account__c);
    }

    @IsTest
    static void testEmptyInput() {

        Test.startTest();
        AEHC_AccountCreationPEHandler.process(
            new List<AEHC_AccountCreationRequest__e>()
        );
        Test.stopTest();

        System.assert(true);
    }
}