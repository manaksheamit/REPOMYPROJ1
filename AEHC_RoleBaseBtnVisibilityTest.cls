@IsTest
private class AEHC_RoleBaseBtnVisibilityTest {

    @IsTest
    static void testButtonVisibility_ReturnsTrue() {

        insert new AEHC_AssetMember__c(
            AEHC_User__c = UserInfo.getUserId(),
            AEHC_Role__c = AEHC_RoleBaseBtnVisibility.SECURITY_ARCHITECT
        );

        Test.startTest();
        Boolean result = AEHC_RoleBaseBtnVisibility.ButtonVisibility();
        Test.stopTest();

        System.assertEquals(true, result);
    }

    @IsTest
    static void testButtonVisibility_ReturnsFalse() {

        insert new AEHC_AssetMember__c(
            AEHC_User__c = UserInfo.getUserId(),
            AEHC_Role__c = 'Asset Owner'
        );

        Test.startTest();
        Boolean result = AEHC_RoleBaseBtnVisibility.ButtonVisibility();
        Test.stopTest();

        System.assertEquals(false, result);
    }
}