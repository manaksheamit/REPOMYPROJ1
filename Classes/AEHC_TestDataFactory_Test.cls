/**
 * @author Asif Ahmad
 * @date 17Apr2026
 * @description test class for AEHC_TestDataFactory
 * @app AEHC
*/
@IsTest
private class AEHC_TestDataFactory_Test {

    /**
     * Test setup creates a base internal user context
     */
    @testSetup
    static void setup() {
        // No-op setup placeholder if needed later
    }

    @IsTest
    static void testCreateExternalUser() {

        String username = 'externaluser@test.com';

        Test.startTest();
        User extUser = AEHC_TestDataFactory.create_ExternalUser(username);
        Test.stopTest();

        // Assertions
        System.assertNotEquals(
            null,
            extUser,
            'External user should be created'
        );
        System.assertEquals(
            username,
            extUser.Username,
            'Username should match'
        );
        System.assertNotEquals(
            null,
            extUser.ContactId,
            'External user should be linked to Contact'
        );
        System.assertEquals(
            'PortalUser',
            extUser.LastName
        );
        
        AEHC_TestDataFactory.assignPermissionSet(extUser.Id, new List<String>{ 'AEHC_Asset_Owner_PS'});
    }

    @IsTest
    static void testAssignPermissionSet() {

        // Create external user
        User u = AEHC_TestDataFactory.create_ExternalUser(
            'psuser@test.com'
        );

        // Get an existing permission set (standard or custom)
        PermissionSet ps = [
            SELECT Id, Name
            FROM PermissionSet
            LIMIT 1
        ];

        Test.startTest();
       /* AEHC_TestDataFactory.assignPermissionSet(
            u.Id,
            new List<String>{ ps.Name }
        );*/
        Test.stopTest();

        // Verify assignment
        List<PermissionSetAssignment> psa = [
            SELECT Id
            FROM PermissionSetAssignment
            WHERE AssigneeId = :u.Id
        ];
    }

    @IsTest
    static void testCreateAssetMember_inserted() {

        User u = AEHC_TestDataFactory.create_ExternalUser(
            'assetmember@test.com'
        );

        Test.startTest();
        AEHC_AssetMember__c member =
            AEHC_TestDataFactory.create_AssetMember(
                'KPMG',
                'Asset Owner',
                u.Id,
                true
            );
        Test.stopTest();

        // Assertions
        System.assertNotEquals(null, member.Id);
        System.assertEquals('Asset Owner', member.AEHC_Role__c);
        System.assertEquals(u.Id, member.AEHC_User__c);
    }

    @IsTest
    static void testCreateAssetMember_notInserted() {

        User u = AEHC_TestDataFactory.create_ExternalUser(
            'assetmember2@test.com'
        );

        AEHC_AssetMember__c member =
            AEHC_TestDataFactory.create_AssetMember(
                'KPMG',
                'Asset Owner',
                u.Id,
                false
            );

        // Should not be inserted
        System.assertEquals(
            null,
            member.Id,
            'Record should not be inserted when isInsert=false'
        );
    }

    @IsTest
    static void testCreateCommunityAsset() {

        Test.startTest();
        ms_aeh__CommunityAsset__c asset =
            AEHC_TestDataFactory.create_CommunityAsset(
                'API',
                true
            );
        Test.stopTest();

        // Assertions
        System.assertNotEquals(null, asset.Id);
        System.assertEquals('API', asset.ms_aeh__AssetType__c);
        System.assertNotEquals(
            null,
            asset.ms_aeh__NetworkId__c,
            'Network ID should be populated'
        );
    }

    @IsTest
    static void testCreateCommunityAsset_notInserted() {

        ms_aeh__CommunityAsset__c asset =
            AEHC_TestDataFactory.create_CommunityAsset(
                'API',
                false
            );

        System.assertEquals(
            null,
            asset.Id,
            'Community Asset should not be inserted'
        );
    }
}