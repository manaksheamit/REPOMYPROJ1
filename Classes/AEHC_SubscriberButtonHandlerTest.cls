@isTest
public class AEHC_SubscriberButtonHandlerTest {

    private static final String PERMSET_NAME = 'AEHC_Developer_PS';
    private static final String PORTAL_PROFILE_NAME = 'API Experience Hub Member User';

    static User portalUser;

    @testSetup
    static void setupData() {

        //Step 1: Create Role
        UserRole role = new UserRole(Name = 'TestRole');
        insert role;

        //Step 2: Create Internal User (Account Owner)
        Profile internalProfile = [
            SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1
        ];

        User owner = new User(
            Alias = 'owner',
            Email = 'owner@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Owner',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = internalProfile.Id,
            TimeZoneSidKey = 'America/New_York',
            Username = 'owner' + DateTime.now().getTime() + '@test.com',
            UserRoleId = role.Id
        );
        insert owner;

        //Step 3: Create Account + Contact inside runAs (NON-SETUP)
        Account acc;
        Contact con;

        System.runAs(owner) {
            acc = new Account(Name = 'Test Account', OwnerId = owner.Id);
            insert acc;

            con = new Contact(
                FirstName = 'Portal',
                LastName = 'User',
                AccountId = acc.Id,
                Email = 'portal@test.com'
            );
            insert con;
        }

        //Step 4: Create Portal User WITH ContactId (SETUP)
        Profile portalProfile = [
            SELECT Id FROM Profile WHERE Name = :PORTAL_PROFILE_NAME LIMIT 1
        ];

        portalUser = new User(
            Username = 'portal' + DateTime.now().getTime() + '@test.com',
            Alias = 'puser',
            Email = 'portal@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'PortalUser',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/New_York',
            ProfileId = portalProfile.Id,
            ContactId = con.Id   
        );
        insert portalUser;

        //Step 5: Assign Permission Set
        PermissionSet ps = [
            SELECT Id FROM PermissionSet WHERE Name = :PERMSET_NAME LIMIT 1
        ];

        insert new PermissionSetAssignment(
            AssigneeId = portalUser.Id,
            PermissionSetId = ps.Id
        );
    }

    @isTest
    static void testCanViewSubscriberButton_True() {

        User u = [SELECT Id FROM User WHERE Alias = 'puser' LIMIT 1];
        insert new AEHC_AssetMember__c(
                AEHC_User__c = u.Id,
                AEHC_Role__c = 'Enterprise Architect'
            );

        System.runAs(u) {
            Test.startTest();
            Boolean result = AEHC_SubscriberButtonHandler.canViewSubscriberButton();
            Test.stopTest();
            System.assertEquals(true, result);
        }
    }
}