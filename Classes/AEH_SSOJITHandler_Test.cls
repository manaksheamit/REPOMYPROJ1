@IsTest
global class AEH_SSOJITHandler_Test {

    /* =====================================================
       TEST SETUP – Custom Setting (Setup Object Only)
    ===================================================== */
    @testSetup
    static void setupConfig() {
        insert new AEHC_Global_Config__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            CLAIM_EMAIL__c =
                'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress',
            CLAIM_GIVENNAME__c =
                'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname',
            CLAIM_SURNAME__c =
                'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname',
            CLAIM_GROUPS__c =
                'http://schemas.microsoft.com/ws/2008/06/identity/claims/groups',
            PORTAL_ACCOUNT_NAME__c = 'Portal Account - Test',
            PROFILE_EXTERNAL_IDENTITY__c = 'API Experience Hub Member User'
        );
    }

    /* =====================================================
       Helper: Create INTERNAL User (System Administrator)
       ✅ NOT a portal user
    ===================================================== */
    private static User createInternalUser() {

        Profile adminProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'System Administrator'
            LIMIT 1
        ];

        UserRole role = new UserRole(Name = 'Internal Role');
        insert role;

        User u = new User(
            Username = 'admin.' + System.currentTimeMillis() + '@test.com',
            Email = 'admin@test.com',
            LastName = 'Admin',
            Alias = 'admin',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = adminProfile.Id,
            UserRoleId = role.Id
        );
        insert u;

        return u;
    }

    /* =====================================================
       Helper: Attributes Map
    ===================================================== */
    private static Map<String,String> samlAttrs() {
        return new Map<String,String>{
            'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress'
                => 'jit@test.com',
            'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname'
                => 'Jit',
            'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname'
                => 'User',
            'http://schemas.microsoft.com/ws/2008/06/identity/claims/groups'
                => 'Test'
        };
    }

    /* =====================================================
       TEST: getContactId()
    ===================================================== */
    @IsTest
    static void testGetContactId() {
        User u = createInternalUser();
        System.runAs(u) {
            AEH_SSOJITHandler h = new AEH_SSOJITHandler();
            h.getContactId('test@test.com', 'Last', 'First');
            h.getContactId('test@test.com', 'Last', 'First');
        }
    }

    /* =====================================================
       TEST: createUser()
    ===================================================== */
    @IsTest
    static void testCreateUser() {
        User u = createInternalUser();
        System.runAs(u) {
            new AEH_SSOJITHandler().createUser(
                null, null, null,
                'fed.' + System.currentTimeMillis(),
                samlAttrs(),
                'assertion'
            );
        }
    }

    /* =====================================================
       TEST: updateUser()
       ✅ Safe because target user is internal
    ===================================================== */
    @IsTest
    static void testUpdateUser() {
        User u = createInternalUser();

        System.runAs(u) {
            Test.startTest();
            new AEH_SSOJITHandler().updateUser(
                u.Id,
                null, null, null,
                'fed',
                samlAttrs(),
                'assertion'
            );
            Test.stopTest();
        }
    }

    /* =====================================================
       TEST: handleJit() – UPDATE PATH ONLY
    ===================================================== */
    @IsTest
    static void testHandleJit_UpdateOnly() {
        User u = createInternalUser();
        System.runAs(u) {
            new AEH_SSOJITHandler()
                .handleJit(false, u, 'fed', samlAttrs());
        }
    }

    /* =====================================================
       TEST: assignPermissionSet()
    ===================================================== */
    @IsTest
    static void testAssignPermissionSet() {
        User u = createInternalUser();
        System.runAs(u) {
            new AEH_SSOJITHandler()
                .assignPermissionSet(u.Id, 'DUMMY_PERMISSION');
        }
    }

    /* =====================================================
       TEST: assignPermission() – @future
    ===================================================== */
    @IsTest
    static void testAssignPermissionFuture() {
        User u = createInternalUser();
        System.runAs(u) {
            Test.startTest();
            AEH_SSOJITHandler.assignPermission(
                u.Id,
                'DUMMY_PERMISSION'
            );
            Test.stopTest();
        }
    }
}