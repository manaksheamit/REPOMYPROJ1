/**
 * @author Asif Ahmad
 * @date 14Apr2026
 * @description Test Class for AEHC_Utility
 * @app AEHC
*/
@IsTest
private class AEHC_UtilityTest {
    
    @IsTest
    static void test_getStringFromMap() {

        Map<String, String> records = new Map<String, String>();
        records.put('name', 'Test_User');
        records.put('email', 'Test_User@g.co');

        Test.startTest();
        String name = AEHC_Utility.getStringFromMap(records, 'name', null);
        Test.stopTest();

        System.assertEquals(
            'Test_User', name,
            'name should be Test_User'
        );
    }
    
    @IsTest
    static void test_getValueAsObjectFromMap() {

        Map<String, String> records = new Map<String, String>();
        records.put('name', 'Test_User');
        records.put('email', 'Test_User@g.co');

        Test.startTest();
        Object name = AEHC_Utility.getValueAsObjectFromMap(records, 'name', null);
        Test.stopTest();
    }
    
    @IsTest
    static void test_getConfig() {
        Test.startTest();
        AEHC_Utility.getConfig();
        Test.stopTest();
    }
    
    @IsTest
    static void test_getAPIConfig() {
        Test.startTest();
        AEHC_Utility.getAPIConfig(AEHC_Constant.CM_API_MuleFlex_Auth);
        Test.stopTest();
    }
    
    @IsTest
    static void test_getCurrentEnvironment() {
        Test.startTest();
        AEHC_Utility.getCurrentEnvironment();
        Test.stopTest();
    }
    
    @IsTest
    static void test_addUserInAsset() {
        Test.startTest();
        AEHC_Utility.addUserInAsset(null, null, null, true);
        Test.stopTest();
    }
    
    @IsTest
    static void test_isValidRecordId() {
        Test.startTest();
        AEHC_Utility.isValidRecordId(UserInfo.getUserId());
        Test.stopTest();
    }
    
    @IsTest
    static void test_upsertRecs() {
        Test.startTest();
        AEHC_Utility.upsertRecs(new List<User>{new User()});
        
        new AEHC_Utility.LookupField();
        new AEHC_Utility.LookupField(null, null, null, false);
        Test.stopTest();
    }
    
    @IsTest
    static void test_getPicklistValues() {
        Test.startTest();
        AEHC_Utility.getPicklistValues('AEHC_Asset__c', 'AEHC_Environment__c');
        Test.stopTest();
    }
    
    @IsTest
    static void test_getRecordTypeId() {
        Test.startTest();
        AEHC_Utility.getRecordTypeId('AEHC_Asset__c', AEHC_Constant.RECORDTYPENAME_ASSET_APPLICATION);
        Test.stopTest();
    }
}