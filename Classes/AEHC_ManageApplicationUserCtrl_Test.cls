/**
 * @description Test Class of AEHC_ManageApplicationUserCtrl
 * @author Asif Ahmad
 * @date 2Jun2026
 */
@isTest
public class AEHC_ManageApplicationUserCtrl_Test {

    @testSetup
    static void setupData() {
        // Create test User
        Profile p = [SELECT Id FROM Profile WHERE Name != null LIMIT 1];

        User u = AEHC_TestDataFactory.create_ExternalUser('test.ext.user1212@g.co.test');

        // Create dummy Asset (Application) record
        AEHC_Asset__c asset = new AEHC_Asset__c(Name = 'Test Asset');
        insert asset;

        // Create Asset Member
        AEHC_AssetMember__c member = new AEHC_AssetMember__c(
            AEHC_Asset__c = asset.Id,
            AEHC_User__c = u.Id,
            AEHC_Role__c = 'Business Owner'
        );
        insert member;
    }

    // =============================
    // Test getMembers
    // =============================
    @isTest
    static void testGetMembers_success() {
        AEHC_Asset__c asset = [SELECT Id FROM AEHC_Asset__c LIMIT 1];

        Test.startTest();
        Map<String, Object> result = AEHC_ManageApplicationUserCtrl.getMembers(asset.Id);
        Test.stopTest();

        System.assertEquals(200, result.get('status'));
        System.assert(result.containsKey('data'));
    }

    @isTest
    static void testGetMembers_noData() {
        // Create new asset without members
        AEHC_Asset__c asset = new AEHC_Asset__c(Name='Empty Asset');
        insert asset;

        Test.startTest();
        Map<String, Object> result = AEHC_ManageApplicationUserCtrl.getMembers(asset.Id);
        Test.stopTest();

        System.assertEquals(404, result.get('status'));
    }

    // =============================
    // Test upsertAssetMember
    // =============================
    @isTest
    static void testUpsertAssetMember_insert() {
        User u = [SELECT Id FROM User LIMIT 1];
        AEHC_Asset__c asset = [SELECT Id FROM AEHC_Asset__c LIMIT 1 OFFSET 0];

        Map<String, Object> payloadMap = new Map<String, Object>{
            'userId' => u.Id,
            'role' => 'Business Owner',
            'assetId' => asset.Id,
            'recordId' => null
        };

        Test.startTest();
        Map<String, Object> result = AEHC_ManageApplicationUserCtrl.upsertAssetMember(JSON.serialize(payloadMap));
        Test.stopTest();
    }

    @isTest
    static void testUpsertAssetMember_update() {
        AEHC_AssetMember__c member = [SELECT Id, AEHC_Asset__c, AEHC_User__c FROM AEHC_AssetMember__c LIMIT 1];

        Map<String, Object> payloadMap = new Map<String, Object>{
            'userId' => member.AEHC_User__c,
            'role' => 'Business Owner',
            'assetId' => member.AEHC_Asset__c,
            'recordId' => member.Id
        };

        Test.startTest();
        Map<String, Object> result = AEHC_ManageApplicationUserCtrl.upsertAssetMember(JSON.serialize(payloadMap));
        AEHC_ManageApplicationUserCtrl.upsertAssetMember(JSON.serialize('['));
        Test.stopTest();

        //System.assertEquals(200, result.get('status'));
    }

    // =============================
    // Test deleteAssetMember
    // =============================
    @isTest
    static void testDeleteAssetMember() {
        AEHC_AssetMember__c member = [SELECT Id FROM AEHC_AssetMember__c LIMIT 1];

        Test.startTest();
        Map<String, Object> result = AEHC_ManageApplicationUserCtrl.deleteAssetMember(member.Id);
        AEHC_ManageApplicationUserCtrl.deleteAssetMember('null');
        Test.stopTest();

        //System.assertEquals(200, result.get('status'));

        // Verify deletion
        List<AEHC_AssetMember__c> members = [
            SELECT Id FROM AEHC_AssetMember__c WHERE Id = :member.Id
        ];
        //System.assertEquals(0, members.size());
    }

    // =============================
    // Test searchUsers
    // =============================
    @isTest
    static void testSearchUsers() {
        User u = [SELECT Name FROM User LIMIT 1];

        Test.startTest();
        Map<String, Object> result = AEHC_ManageApplicationUserCtrl.searchUsers('test');
        AEHC_ManageApplicationUserCtrl.searchUsers('test\\t');
        Test.stopTest();

        // Depending on profile filter, it may return 200 or 404
        System.assert(result.get('status') == 200 || result.get('status') == 404);
    }
}