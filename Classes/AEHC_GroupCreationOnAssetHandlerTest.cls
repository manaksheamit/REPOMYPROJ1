/*@description This test class covers test scenerios for AEHC_GroupCreationOnAssetHandler.
 * @author Himanshu Singh
 * @version 1.0
 */
@isTest
private class AEHC_GroupCreationOnAssetHandlerTest {

    @isTest
    static void testAccountCreation_NewAccounts() {
        // Existing Account
        Account existingAcc = new Account(Name = 'Asset A');
        insert existingAcc;
        Id recordTypeId_Asset_App = AEHC_Utility.getRecordTypeId('AEHC_Asset__c', AEHC_Constant.RECORDTYPENAME_ASSET_APPLICATION);

        // Create Asset records with unique names
        AEHC_Asset__c asset1 = new AEHC_Asset__c(Name = 'Asset A', RecordTypeId = recordTypeId_Asset_App);
        AEHC_Asset__c asset2 = new AEHC_Asset__c(Name = 'Asset B', RecordTypeId = recordTypeId_Asset_App);

        insert new List<AEHC_Asset__c>{asset1, asset2};
       
    }
}