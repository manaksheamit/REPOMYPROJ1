/**
 * @author Asif Ahmad
 * @date 17Apr2026
 * @description Test Class for AEHC_APIDashboardCtrl
 * @app AEHC
*/
@isTest
public class AEHC_APIDashboardCtrl_Test {
    
    final static String TestUsername = 'johndoe.test@kpmg.test12345';

    @TestSetup
    static void setupData() {

        // Create Portal User
        final User portalUser = AEHC_TestDataFactory.create_ExternalUser(TestUsername);
        
        String assetOwnerName = 'LDAP-QUEUE';
        ms_aeh__CommunityAsset__c asset = AEHC_TestDataFactory.create_CommunityAsset('graph', false);
        asset.AEHC_APIAssetOwner__c = assetOwnerName;
        insert asset;
        
        AEHC_Utility.addUserInAsset(asset.Id, portalUser.Id, AEHC_Constant.ASSET_OWNER, true);
        
    }
    
    @isTest
    public static void testAll() {
        Test.setMock(HttpCalloutMock.class, new AEHC_Mule_GetAPIService_Test.CalloutMocker('{"data":{"assets":[{"contactName":"LDAP-QUEUE","type":"rest-api"},{"contactName":"LDAP-QUEUE","type":"rest-api"},{"contactName":"LDAP-QUEUE","type":"http-api"},{"contactName":"HTTP-QUEUE","type":"graph-api"}]}}'));

        User testUser = [SELECT Id FROM User WHERE Username = :TestUsername];
        Map<String, Object> result;
        System.runAs(testUser) {
            
            Test.startTest();
            result = AEHC_APIDashboardCtrl.getPublishedAPIMatrix();
            Test.stopTest();
        }
        
        Map<String, Integer> dataMatrix = new Map<String, Integer>(); 
        if(Integer.valueOf(result.get('status')) == 200) {
            dataMatrix = (Map<String, Integer>)result.get('data');
        }
        // Validate map contains expected keys
        System.assert(
            dataMatrix.containsKey('rest-api'),
            'Expected rest-api to be returned in summary.'
        );

        System.assert(
            !dataMatrix.containsKey('graph-api'),
            'Expected graph-api not to be returned in summary.'
        );

        // Validate counts
        System.assertEquals(
            2,
            dataMatrix.get('rest-api'),
            'rest-api should have count = 2.'
        );
    }
}