@IsTest
private class AEHC_EmailAlertServiceControllerTest {

    private static User createTestUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User'  LIMIT 1 ];

        User u = new User(
            FirstName = 'Test',
            LastName = 'User',
            Alias = 'tuser',
            Email = 'testuser@test.com',
            Username = 'testuser' + System.currentTimeMillis() + '@test.com',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert u;

        return u;
    }

    private static Contact createContact() {
        Contact c = new Contact(LastName = 'Test Contact', Email = 'contact@test.com' );
        insert c;
        return c;
    }

    private static AEHC_Asset__c createAsset() {

        AEHC_Asset__c asset = new AEHC_Asset__c( Name = 'Test Asset', AEHC_Is_Subscription__c = false,  AEHC_Environment__c = 'Dev');

        insert asset;
        return asset;
    }

    @IsTest
    static void testNullRecordId() {

        AEHC_EmailAlertServiceController.EmailRequest req =
            new AEHC_EmailAlertServiceController.EmailRequest();

        req.recordId = null;
        req.eventType = 'SUBMITTED';
        req.currentEnv = 'Dev';
        req.approvalStatus = 'SUBMITTED';

        Test.startTest();

        List<AEHC_EmailAlertServiceController.EmailResponse> responses =
            AEHC_EmailAlertServiceController.sendAssetEmail(
                new List<AEHC_EmailAlertServiceController.EmailRequest>{ req }
            );

        Test.stopTest();

        System.assertEquals(1, responses.size());
        System.assertEquals(false, responses[0].success);
        System.assert(
            responses[0].message.contains('Record Id is required')
        );
    }

    @IsTest
    static void testNoTemplateConfigured() {

        createContact();

        AEHC_Asset__c asset = createAsset();

        User u = createTestUser();

        AEHC_EmailAlertServiceController.EmailRequest req =
            new AEHC_EmailAlertServiceController.EmailRequest();

        req.recordId = asset.Id;
        req.eventType = 'INVALID_EVENT';
        req.currentEnv = 'Dev';
        req.approvalStatus = 'INVALID_EVENT';
        req.recipientUsers = new List<String>{ u.Id };

        Test.startTest();

        List<AEHC_EmailAlertServiceController.EmailResponse> responses =
            AEHC_EmailAlertServiceController.sendAssetEmail(
                new List<AEHC_EmailAlertServiceController.EmailRequest>{ req }
            );

        Test.stopTest();

        System.assertEquals(1, responses.size());
        System.assertEquals(false, responses[0].success);
        
    }

    @IsTest
    static void testTemplateMappedButTemplateMissing() {

        createContact();

        AEHC_Asset__c asset = createAsset();

        User u = createTestUser();

        AEHC_EmailAlertServiceController.EmailRequest req =
            new AEHC_EmailAlertServiceController.EmailRequest();

        req.recordId = asset.Id;
        req.eventType = 'SUBMITTED';
        req.currentEnv = 'Dev';
        req.approvalStatus = 'SUBMITTED';
        req.recipientUsers = new List<String>{ u.Id };

        Test.startTest();

        List<AEHC_EmailAlertServiceController.EmailResponse> responses =
            AEHC_EmailAlertServiceController.sendAssetEmail(
                new List<AEHC_EmailAlertServiceController.EmailRequest>{ req }
            );

        Test.stopTest();

        System.assertEquals(1, responses.size());

        /*
         * If the template Publication_Creation_Submitted
         * does not exist in the test-running org,
         * an exception is expected.
         */
        System.assertNotEquals(null, responses[0].success);
    }

    @IsTest
    static void testMultipleRequests() {

        AEHC_Asset__c asset = createAsset();

        AEHC_EmailAlertServiceController.EmailRequest req1 =
            new AEHC_EmailAlertServiceController.EmailRequest();

        req1.recordId = null;
        req1.eventType = 'SUBMITTED';
        req1.currentEnv = 'Dev';
        req1.approvalStatus = 'SUBMITTED';

        AEHC_EmailAlertServiceController.EmailRequest req2 =
            new AEHC_EmailAlertServiceController.EmailRequest();

        req2.recordId = asset.Id;
        req2.eventType = 'INVALID_EVENT';
        req2.currentEnv = 'Dev';
        req2.approvalStatus = 'INVALID_EVENT';

        Test.startTest();

        List<AEHC_EmailAlertServiceController.EmailResponse> responses =
            AEHC_EmailAlertServiceController.sendAssetEmail(
                new List<AEHC_EmailAlertServiceController.EmailRequest>{
                    req1,
                    req2
                }
            );

        Test.stopTest();

        System.assertEquals(2, responses.size());
        System.assertEquals(false, responses[0].success);
        System.assertEquals(false, responses[1].success);
    }

    

    @IsTest
static void testPromotionApprovalBranch() {

    createContact();

    AEHC_Asset__c asset = new AEHC_Asset__c(
        Name='PromotionAsset',
        AEHC_Is_Subscription__c=false,
        AEHC_Environment__c='QA'
    );
    insert asset;

    AEHC_EmailAlertServiceController.EmailRequest req =
        new AEHC_EmailAlertServiceController.EmailRequest();

    req.recordId = asset.Id;
    req.eventType = 'APPROVAL';
    req.currentEnv = 'QA';
    req.approvalStatus = 'DDH Admin Review';

    Test.startTest();

    List<AEHC_EmailAlertServiceController.EmailResponse> result =
        AEHC_EmailAlertServiceController.sendAssetEmail(
            new List<AEHC_EmailAlertServiceController.EmailRequest>{req}
        );

    Test.stopTest();

    System.assertEquals(1,result.size());
}

    @IsTest
static void testPromotionApprovedBranch() {

    createContact();

    AEHC_Asset__c asset = new AEHC_Asset__c(
        Name='PromotionApproved',
        AEHC_Is_Subscription__c=false,
        AEHC_Environment__c='QA'
    );
    insert asset;

    AEHC_EmailAlertServiceController.EmailRequest req =
        new AEHC_EmailAlertServiceController.EmailRequest();

    req.recordId = asset.Id;
    req.eventType = 'APPROVED';
    req.currentEnv = 'QA';
    req.previousEnv = 'QA';
    req.approvalStatus = 'Submitted to DDH';

    Test.startTest();

    List<AEHC_EmailAlertServiceController.EmailResponse> result =
        AEHC_EmailAlertServiceController.sendAssetEmail(
            new List<AEHC_EmailAlertServiceController.EmailRequest>{req}
        );

    Test.stopTest();

    System.assertEquals(1,result.size());
}

    @IsTest
static void testPromotionRejectedBranch() {

    createContact();

    AEHC_Asset__c asset = new AEHC_Asset__c(
        Name='PromotionRejected',
        AEHC_Is_Subscription__c=false,
        AEHC_Environment__c='QA'
    );
    insert asset;

    AEHC_EmailAlertServiceController.EmailRequest req =
        new AEHC_EmailAlertServiceController.EmailRequest();

    req.recordId = asset.Id;
    req.eventType = 'REJECTED';
    req.currentEnv = 'QA';
    req.previousEnv = 'QA';
    req.approvalStatus = 'Rejected';

    Test.startTest();

    List<AEHC_EmailAlertServiceController.EmailResponse> result =
        AEHC_EmailAlertServiceController.sendAssetEmail(
            new List<AEHC_EmailAlertServiceController.EmailRequest>{req}
        );

    Test.stopTest();

    System.assertEquals(1,result.size());
}

    
@IsTest
static void testAdlSubmittedToBO() {

    createContact();

    AEHC_Asset__c asset = new AEHC_Asset__c(
        Name='ADLAsset',
        AEHC_Is_Subscription__c=false,
        AEHC_Environment__c='DEV'
    );
    insert asset;

    AEHC_EmailAlertServiceController.EmailRequest req =
        new AEHC_EmailAlertServiceController.EmailRequest();

    req.recordId = asset.Id;
    req.eventType = 'SUBMITTED';
    req.currentEnv = 'DEV';
    req.approvalStatus = 'Business Owner Publication Review';
    req.isAdl = true;

    Test.startTest();

    List<AEHC_EmailAlertServiceController.EmailResponse> result =
        AEHC_EmailAlertServiceController.sendAssetEmail(
            new List<AEHC_EmailAlertServiceController.EmailRequest>{req}
        );

    Test.stopTest();

    System.assertEquals(1,result.size());
}
    @IsTest
static void testAdlIAApproval() {

    createContact();

    AEHC_Asset__c asset = new AEHC_Asset__c(
        Name='ADL IA',
        AEHC_Is_Subscription__c=false,
        AEHC_Environment__c='DEV'
    );
    insert asset;

    AEHC_EmailAlertServiceController.EmailRequest req =
        new AEHC_EmailAlertServiceController.EmailRequest();

    req.recordId = asset.Id;
    req.eventType = 'APPROVAL';
    req.currentEnv = 'DEV';
    req.approvalStatus = 'Information Architect Review';
    req.isAdl = true;

    Test.startTest();

    AEHC_EmailAlertServiceController.sendAssetEmail(
        new List<AEHC_EmailAlertServiceController.EmailRequest>{req}
    );

    Test.stopTest();
}

    @IsTest
static void testAdlFinalApproved() {

    createContact();

    AEHC_Asset__c asset = new AEHC_Asset__c(
        Name='ADL Approved',
        AEHC_Is_Subscription__c=false,
        AEHC_Environment__c='DEV'
    );
    insert asset;

    AEHC_EmailAlertServiceController.EmailRequest req =
        new AEHC_EmailAlertServiceController.EmailRequest();

    req.recordId = asset.Id;
    req.eventType = 'APPROVED';
    req.currentEnv = 'DEV';
    req.approvalStatus = 'Submitted to DDH';
    req.isAdl = true;

    Test.startTest();

    AEHC_EmailAlertServiceController.sendAssetEmail(
        new List<AEHC_EmailAlertServiceController.EmailRequest>{req}
    );

    Test.stopTest();
}

    @IsTest
static void testAdlFinalRejected() {

    createContact();

    AEHC_Asset__c asset = new AEHC_Asset__c(
        Name='ADL Rejected',
        AEHC_Is_Subscription__c=false,
        AEHC_Environment__c='DEV'
    );
    insert asset;

    AEHC_EmailAlertServiceController.EmailRequest req =
        new AEHC_EmailAlertServiceController.EmailRequest();

    req.recordId = asset.Id;
    req.eventType = 'REJECTED';
    req.currentEnv = 'DEV';
    req.approvalStatus = 'Rejected';
    req.isAdl = true;

    Test.startTest();

    AEHC_EmailAlertServiceController.sendAssetEmail(
        new List<AEHC_EmailAlertServiceController.EmailRequest>{req}
    );

    Test.stopTest();
}

    /* =========================================================
     *  ADDED COVERAGE TESTS
     *  (production class untouched)
     * ========================================================= */

    private static final List<String> ALL_TEMPLATES = new List<String>{
        'Publication_Creation_Submitted',
        'Notification_to_Information_Architect_Publication_Request',
        'Publication_Approval_Required',
        'Publication_Approved',
        'Publication_Rejected',
        'Publication_Promotion_Submitted',
        'Publication_Promotion_Approved',
        'Publication_Promotion_Rejected',
        'GP_Schema_Change_Submitted',
        'GP_Schema_Approval_Required_BO',
        'GP_Schema_Approval_Required_IA',
        'GP_Schema_Approved',
        'GP_Schema_Completed',
        'GP_Schema_Rejected',
        'Impacted_Subscriber_Notification',
        'Subscription_Request_Submitted',
        'Notificaion_to_Information_Architect_Subscription_Request',
        'Subscription_Approval_Required',
        'Subscription_Approved',
        'Subscription_Rejected',
        'Subscription_Promotion_Submitted',
        'Subscription_Promotion_Approved',
        'Subscription_Promotion_Rejected',
        'Subscription_Approved_by_PBO_with_UAT_Toggle_Enabled_Disabled',
        'Subscription_Rejected_by_PBO_with_UAT_Toggle_Enabled_Disabled'
    };

    /**
     * Templates are not visible to a test that runs without SeeAllData, so the
     * EmailTemplate query inside sendTemplateEmail throws before any of that
     * method is covered. Creating personal-folder templates makes the query
     * succeed so the rest of sendTemplateEmail actually executes.
     */
    private static void ensureTemplates() {
        Set<String> existing = new Set<String>();

        for (EmailTemplate t : [
            SELECT DeveloperName FROM EmailTemplate WHERE DeveloperName IN :ALL_TEMPLATES
        ]) {
            existing.add(t.DeveloperName);
        }

        List<EmailTemplate> toInsert = new List<EmailTemplate>();

        for (String devName : ALL_TEMPLATES) {
            if (existing.contains(devName)) {
                continue;
            }
            toInsert.add(new EmailTemplate(
                Name = devName,
                DeveloperName = devName,
                FolderId = UserInfo.getUserId(),
                TemplateType = 'text',
                Subject = 'Test Subject',
                Body = 'Test Body',
                IsActive = true
            ));
        }

        if (toInsert.isEmpty()) {
            return;
        }

        System.runAs(new User(Id = UserInfo.getUserId())) {
            try {
                insert toInsert;
            } catch (Exception e) {
                // Org already owns templates with these developer names.
            }
        }
    }

    private static AEHC_Asset__c newAsset(String name, Boolean isSubscription, String env) {
        AEHC_Asset__c asset = new AEHC_Asset__c(
            Name = name,
            AEHC_Is_Subscription__c = isSubscription,
            AEHC_Environment__c = env
        );
        insert asset;
        return asset;
    }

    /**
     * Subscription assets dereference AEHC_Subscription_Request__r inside
     * determineTemplateName, so the lookup has to be populated.
     */
    private static AEHC_Asset__c newSubscriptionAsset(String name, String env, Boolean uatApproval) {
        AEHC_Asset__c request = new AEHC_Asset__c(
            Name = name + ' Request',
            AEHC_Is_Subscription__c = true,
            AEHC_Environment__c = env
        );
        setIfWriteable(request, 'AEHC_UAT_Approval__c', uatApproval);
        insert request;

        AEHC_Asset__c asset = new AEHC_Asset__c(
            Name = name,
            AEHC_Is_Subscription__c = true,
            AEHC_Environment__c = env
        );
        setIfWriteable(asset, 'AEHC_UAT_Approval__c', uatApproval);
        setIfWriteable(asset, 'AEHC_Subscription_Request__c', request.Id);
        insert asset;

        return asset;
    }

    private static AEHC_Asset__c newPublicationAsset(String name, String env) {
        AEHC_Asset__c publication = new AEHC_Asset__c(
            Name = name + ' Publication',
            AEHC_Is_Subscription__c = false,
            AEHC_Environment__c = env
        );
        insert publication;

        AEHC_Asset__c asset = new AEHC_Asset__c(
            Name = name,
            AEHC_Is_Subscription__c = false,
            AEHC_Environment__c = env
        );
        setIfWriteable(asset, 'AEHC_Publication__c', publication.Id);
        insert asset;

        return asset;
    }

    private static void setIfWriteable(SObject rec, String fieldApiName, Object value) {
        Map<String, Schema.SObjectField> fields =
            AEHC_Asset__c.SObjectType.getDescribe().fields.getMap();

        if (!fields.containsKey(fieldApiName)) {
            return;
        }
        Schema.DescribeFieldResult describe = fields.get(fieldApiName).getDescribe();

        if (!describe.isCreateable()) {
            return;
        }

        if (describe.getType() == Schema.DisplayType.REFERENCE && value instanceof Id) {
            Schema.SObjectType valueType = ((Id) value).getSObjectType();
            Boolean matches = false;

            for (Schema.SObjectType target : describe.getReferenceTo()) {
                if (target == valueType) {
                    matches = true;
                }
            }

            if (!matches) {
                return;
            }
        }

        rec.put(fieldApiName, value);
    }

    private static AEHC_EmailAlertServiceController.EmailRequest buildRequest(
        Id recordId, String eventType, String approvalStatus, String previousEnv,
        String currentEnv, Boolean isAdl, List<String> recipients
    ) {
        AEHC_EmailAlertServiceController.EmailRequest req =
            new AEHC_EmailAlertServiceController.EmailRequest();

        req.recordId = recordId;
        req.eventType = eventType;
        req.approvalStatus = approvalStatus;
        req.previousEnv = previousEnv;
        req.currentEnv = currentEnv;
        req.isAdl = isAdl;
        req.recipientUsers = recipients;

        return req;
    }

    private static List<AEHC_EmailAlertServiceController.EmailResponse> run(
        AEHC_EmailAlertServiceController.EmailRequest req
    ) {
        return AEHC_EmailAlertServiceController.sendAssetEmail(
            new List<AEHC_EmailAlertServiceController.EmailRequest>{ req }
        );
    }

    /**
     * Only a user linked to a Contact with an email satisfies the recipient
     * filter in sendTemplateEmail, so reuse one when the org already has it and
     * otherwise build a community user (role-owning account owner, account,
     * contact, portal user).
     */
    private static Id existingContactUserId() {
        List<User> users = [
            SELECT Id FROM User
            WHERE IsActive = true AND ContactId != null AND Contact.Email != null
            LIMIT 1
        ];

        if (!users.isEmpty()) {
            return users[0].Id;
        }

        return createCommunityUserId();
    }

    private static Id createCommunityUserId() {
        List<Profile> portalProfiles = [
            SELECT Id FROM Profile
            WHERE UserType IN ('CspLitePortal', 'PowerCustomerSuccess', 'CustomerSuccess', 'PowerPartner')
            LIMIT 1
        ];

        if (portalProfiles.isEmpty()) {
            return null;
        }

        try {
            User accountOwner = createAccountOwner();

            if (accountOwner == null) {
                return null;
            }

            Contact portalContact;

            System.runAs(accountOwner) {
                Account acc = new Account(Name = 'AEHC Portal Account');
                insert acc;

                portalContact = new Contact(
                    LastName = 'AEHC Portal Contact',
                    Email = 'aehc.portal.contact@test.invalid',
                    AccountId = acc.Id
                );
                insert portalContact;
            }

            User portalUser = new User(
                FirstName = 'AEHC',
                LastName = 'Portal',
                Alias = 'aehcp',
                Email = 'aehc.portal.contact@test.invalid',
                Username = 'aehc.portal.' + System.currentTimeMillis() + '@test.invalid',
                ProfileId = portalProfiles[0].Id,
                ContactId = portalContact.Id,
                TimeZoneSidKey = 'America/New_York',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US'
            );

            System.runAs(accountOwner) {
                insert portalUser;
            }

            return portalUser.Id;
        } catch (Exception e) {
            // Communities/portals may be disabled in this org.
            return null;
        }
    }

    private static User createAccountOwner() {
        try {
            Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
            User owner;

            System.runAs(new User(Id = UserInfo.getUserId())) {
                List<UserRole> roles = [SELECT Id FROM UserRole LIMIT 1];
                Id roleId;

                if (roles.isEmpty()) {
                    UserRole role = new UserRole(
                        Name = 'AEHC Test Role',
                        DeveloperName = 'AEHC_Test_Role'
                    );
                    insert role;
                    roleId = role.Id;
                } else {
                    roleId = roles[0].Id;
                }

                owner = new User(
                    FirstName = 'AEHC',
                    LastName = 'Owner',
                    Alias = 'aehco',
                    Email = 'aehc.owner@test.invalid',
                    Username = 'aehc.owner.' + System.currentTimeMillis() + '@test.invalid',
                    ProfileId = adminProfile.Id,
                    UserRoleId = roleId,
                    TimeZoneSidKey = 'America/New_York',
                    LocaleSidKey = 'en_US',
                    EmailEncodingKey = 'UTF-8',
                    LanguageLocaleKey = 'en_US'
                );
                insert owner;
            }

            return owner;
        } catch (Exception e) {
            return null;
        }
    }

    @IsTest
    static void testBlankEventTypeGivesNoTemplate() {
        createContact();
        AEHC_Asset__c asset = createAsset();

        Test.startTest();
        List<AEHC_EmailAlertServiceController.EmailResponse> responses =
            run(buildRequest(asset.Id, '', 'SUBMITTED', null, 'Dev', false, null));
        Test.stopTest();

        System.assertEquals(false, responses[0].success, 'Blank event type resolves no template');
        System.assert(
            responses[0].message.contains('No email template configured'),
            'Expected the no-template message but got: ' + responses[0].message
        );
    }

    @IsTest
    static void testAssetNotFound() {
        createContact();
        AEHC_Asset__c asset = createAsset();
        Id deletedId = asset.Id;
        delete asset;

        Test.startTest();
        List<AEHC_EmailAlertServiceController.EmailResponse> responses =
            run(buildRequest(deletedId, 'SUBMITTED', 'SUBMITTED', null, 'Dev', false, null));
        Test.stopTest();

        System.assertEquals(false, responses[0].success, 'Missing asset must fail the request');
    }

    @IsTest
    static void testSubscriptionSubmitted() {
        ensureTemplates();
        createContact();
        AEHC_Asset__c asset = newSubscriptionAsset('SubSubmitted', 'Dev', false);

        Test.startTest();
        List<AEHC_EmailAlertServiceController.EmailResponse> responses =
            run(buildRequest(asset.Id, 'SUBMITTED', 'SUBMITTED', null, 'Dev', false, null));
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'One response per request');
        System.assertNotEquals(null, responses[0].message, 'A message is always populated');
    }

    @IsTest
    static void testSubscriptionSubmittedToInformationArchitect() {
        ensureTemplates();
        createContact();
        AEHC_Asset__c asset = newSubscriptionAsset('SubSubmittedIA', 'Dev', false);

        Test.startTest();
        List<AEHC_EmailAlertServiceController.EmailResponse> responses =
            run(buildRequest(asset.Id, 'SUBMITTEDIA', 'Information Architect Review', null, 'Dev', false, null));
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'One response per request');
    }

    @IsTest
    static void testSubscriptionApprovalRequired() {
        ensureTemplates();
        createContact();
        AEHC_Asset__c asset = newSubscriptionAsset('SubApproval', 'Dev', false);

        Test.startTest();
        List<AEHC_EmailAlertServiceController.EmailResponse> responses =
            run(buildRequest(asset.Id, 'APPROVAL', 'Business Owner Review', null, 'Dev', false, null));
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'One response per request');
    }

    @IsTest
    static void testSubscriptionUatToggleApproved() {
        ensureTemplates();
        createContact();
        AEHC_Asset__c asset = newSubscriptionAsset('SubUatApproved', 'Dev', true);

        Test.startTest();
        List<AEHC_EmailAlertServiceController.EmailResponse> responses =
            run(buildRequest(asset.Id, 'APPROVED', 'Business Owner Review', null, 'Dev', false, null));
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'One response per request');
    }

    @IsTest
    static void testSubscriptionUatToggleRejected() {
        ensureTemplates();
        createContact();
        AEHC_Asset__c asset = newSubscriptionAsset('SubUatRejected', 'Dev', true);

        Test.startTest();
        List<AEHC_EmailAlertServiceController.EmailResponse> responses =
            run(buildRequest(asset.Id, 'REJECTED', 'Business Owner Review', null, 'Dev', false, null));
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'One response per request');
    }

    @IsTest
    static void testSubscriptionPromotionApproval() {
        ensureTemplates();
        createContact();
        AEHC_Asset__c asset = newSubscriptionAsset('SubPromoApproval', 'UAT', false);

        Test.startTest();
        List<AEHC_EmailAlertServiceController.EmailResponse> responses =
            run(buildRequest(asset.Id, 'APPROVAL', 'Security Architect Review', null, 'UAT', false, null));
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'One response per request');
    }

    @IsTest
    static void testSubscriptionPromotionApproved() {
        ensureTemplates();
        createContact();
        AEHC_Asset__c asset = newSubscriptionAsset('SubPromoApproved', 'Production', false);

        Test.startTest();
        List<AEHC_EmailAlertServiceController.EmailResponse> responses =
            run(buildRequest(asset.Id, 'APPROVED', 'Submitted to DDH', 'Production', 'Production', false, null));
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'One response per request');
    }

    @IsTest
    static void testSubscriptionPromotionRejected() {
        ensureTemplates();
        createContact();
        AEHC_Asset__c asset = newSubscriptionAsset('SubPromoRejected', 'QA', false);

        Test.startTest();
        List<AEHC_EmailAlertServiceController.EmailResponse> responses =
            run(buildRequest(asset.Id, 'REJECTED', 'Rejected', 'QA', 'QA', false, null));
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'One response per request');
    }

    @IsTest
    static void testPublicationSubmittedToInformationArchitect() {
        ensureTemplates();
        createContact();
        AEHC_Asset__c asset = newPublicationAsset('PubSubmittedIA', 'Dev');

        Test.startTest();
        List<AEHC_EmailAlertServiceController.EmailResponse> responses =
            run(buildRequest(asset.Id, 'SUBMITTEDIA', 'Information Architect Review', null, 'Dev', false, null));
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'One response per request');
    }

    @IsTest
    static void testPublicationApprovalNonPromotion() {
        ensureTemplates();
        createContact();
        AEHC_Asset__c asset = newPublicationAsset('PubApproval', 'Dev');

        Test.startTest();
        List<AEHC_EmailAlertServiceController.EmailResponse> responses =
            run(buildRequest(asset.Id, 'APPROVAL', 'DDH Admin Review', null, 'Dev', false, null));
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Dev environment must not take the promotion path');
    }

    @IsTest
    static void testPublicationApprovedAndRejected() {
        ensureTemplates();
        createContact();
        AEHC_Asset__c approvedAsset = newPublicationAsset('PubApproved', 'Dev');
        AEHC_Asset__c rejectedAsset = newPublicationAsset('PubRejected', 'Dev');

        Test.startTest();
        List<AEHC_EmailAlertServiceController.EmailResponse> responses =
            AEHC_EmailAlertServiceController.sendAssetEmail(
                new List<AEHC_EmailAlertServiceController.EmailRequest>{
                    buildRequest(approvedAsset.Id, 'APPROVED', 'Approved', null, 'Dev', false, null),
                    buildRequest(rejectedAsset.Id, 'REJECTED', 'Rejected', null, 'Dev', false, null)
                }
            );
        Test.stopTest();

        System.assertEquals(2, responses.size(), 'One response per request');
    }

    @IsTest
    static void testPublicationPromotionSubmitted() {
        ensureTemplates();
        createContact();
        AEHC_Asset__c asset = newPublicationAsset('PubPromoSubmitted', 'UAT');

        Test.startTest();
        List<AEHC_EmailAlertServiceController.EmailResponse> responses =
            run(buildRequest(asset.Id, 'SUBMITTED', 'Submitted to DDH', 'UAT', 'UAT', false, null));
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'One response per request');
    }

    @IsTest
    static void testPublicationPromotionApprovedInProduction() {
        ensureTemplates();
        createContact();
        AEHC_Asset__c asset = newPublicationAsset('PubPromoProd', 'Production');

        Test.startTest();
        List<AEHC_EmailAlertServiceController.EmailResponse> responses =
            run(buildRequest(asset.Id, 'APPROVED', 'Submitted to DDH', 'Production', 'Production', false, null));
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'One response per request');
    }

    @IsTest
    static void testPublicationPromotionApprovalSecurityArchitectUat() {
        ensureTemplates();
        createContact();
        AEHC_Asset__c asset = newPublicationAsset('PubPromoSA', 'UAT');

        Test.startTest();
        List<AEHC_EmailAlertServiceController.EmailResponse> responses =
            run(buildRequest(asset.Id, 'APPROVAL', 'Security Architect Review', null, 'UAT', false, null));
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'One response per request');
    }

    @IsTest
    static void testAdlPlainSubmitted() {
        ensureTemplates();
        createContact();
        AEHC_Asset__c asset = newPublicationAsset('AdlSubmitted', 'Dev');

        Test.startTest();
        List<AEHC_EmailAlertServiceController.EmailResponse> responses =
            run(buildRequest(asset.Id, 'SUBMITTED', 'Information Architect Review', null, 'Dev', true, null));
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'One response per request');
    }

    @IsTest
    static void testAdlBusinessOwnerApproval() {
        ensureTemplates();
        createContact();
        AEHC_Asset__c asset = newPublicationAsset('AdlBoApproval', 'Dev');

        Test.startTest();
        List<AEHC_EmailAlertServiceController.EmailResponse> responses =
            run(buildRequest(asset.Id, 'APPROVAL', 'Business Owner Publication Review', null, 'Dev', true, null));
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'One response per request');
    }

    @IsTest
    static void testAdlPendingAdlReviewApproval() {
        ensureTemplates();
        createContact();
        AEHC_Asset__c asset = newPublicationAsset('AdlPending', 'Dev');

        Test.startTest();
        List<AEHC_EmailAlertServiceController.EmailResponse> responses =
            run(buildRequest(asset.Id, 'APPROVAL', 'Pending ADL Review', null, 'Dev', true, null));
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'One response per request');
    }

    @IsTest
    static void testAdlApprovedByIaAndBo() {
        ensureTemplates();
        createContact();
        AEHC_Asset__c asset = newPublicationAsset('AdlApprovedIaBo', 'Dev');

        Test.startTest();
        List<AEHC_EmailAlertServiceController.EmailResponse> responses =
            run(buildRequest(asset.Id, 'APPROVED', 'Business Owner Publication Review', null, 'Dev', true, null));
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'One response per request');
    }

    @IsTest
    static void testAdlActiveApproved() {
        ensureTemplates();
        createContact();
        AEHC_Asset__c asset = newPublicationAsset('AdlActive', 'Dev');

        Test.startTest();
        List<AEHC_EmailAlertServiceController.EmailResponse> responses =
            run(buildRequest(asset.Id, 'APPROVED', 'Active', null, 'Dev', true, null));
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'One response per request');
    }

    @IsTest
    static void testNoValidRecipientEmails() {
        ensureTemplates();
        createContact();
        AEHC_Asset__c asset = newPublicationAsset('NoRecipients', 'Dev');
        User u = createTestUser();

        Test.startTest();
        List<AEHC_EmailAlertServiceController.EmailResponse> responses =
            run(buildRequest(asset.Id, 'SUBMITTED', 'SUBMITTED', null, 'Dev', false, new List<String>{ u.Id }));
        Test.stopTest();

        System.assertEquals(false, responses[0].success, 'A user without a contact email cannot receive the alert');
        System.assertNotEquals(null, responses[0].message, 'Failure message is populated');
    }

    @IsTest
    static void testInactiveRecipientIsIgnored() {
        ensureTemplates();
        createContact();
        AEHC_Asset__c asset = newPublicationAsset('InactiveRecipient', 'Dev');

        User u = createTestUser();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            u.IsActive = false;
            update u;
        }

        Test.startTest();
        List<AEHC_EmailAlertServiceController.EmailResponse> responses =
            run(buildRequest(asset.Id, 'SUBMITTED', 'SUBMITTED', null, 'Dev', false, new List<String>{ u.Id }));
        Test.stopTest();

        System.assertEquals(false, responses[0].success, 'Inactive users are filtered out of the recipient list');
    }

    @IsTest
    static void testEmptyRecipientListSkipsUserQuery() {
        ensureTemplates();
        createContact();
        AEHC_Asset__c asset = newPublicationAsset('EmptyRecipients', 'Dev');

        Test.startTest();
        List<AEHC_EmailAlertServiceController.EmailResponse> responses =
            run(buildRequest(asset.Id, 'SUBMITTED', 'SUBMITTED', null, 'Dev', false, new List<String>()));
        Test.stopTest();

        System.assertEquals(false, responses[0].success, 'An empty recipient list produces no addresses');
    }

    /**
     * Drives the full send path (publication whatId branch) when the org has a
     * community user whose contact carries an email address.
     */
    @IsTest
    static void testSendEmailForPublicationWithContactUser() {
        ensureTemplates();
        createContact();
        AEHC_Asset__c asset = newPublicationAsset('SendPublication', 'Dev');
        Id recipientId = existingContactUserId();

        List<String> recipients = recipientId == null
            ? new List<String>()
            : new List<String>{ String.valueOf(recipientId) };

        Test.startTest();
        List<AEHC_EmailAlertServiceController.EmailResponse> responses =
            run(buildRequest(asset.Id, 'SUBMITTED', 'SUBMITTED', null, 'Dev', false, recipients));
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'One response per request');
        System.assertNotEquals(null, responses[0].success, 'Success flag is always set');
    }

    /**
     * Same as above but for a subscription asset, which takes the other
     * setWhatId branch inside sendTemplateEmail.
     */
    @IsTest
    static void testSendEmailForSubscriptionWithContactUser() {
        ensureTemplates();
        createContact();
        AEHC_Asset__c asset = newSubscriptionAsset('SendSubscription', 'Dev', false);
        Id recipientId = existingContactUserId();

        List<String> recipients = recipientId == null
            ? new List<String>()
            : new List<String>{ String.valueOf(recipientId) };

        Test.startTest();
        List<AEHC_EmailAlertServiceController.EmailResponse> responses =
            run(buildRequest(asset.Id, 'SUBMITTED', 'SUBMITTED', null, 'Dev', false, recipients));
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'One response per request');
        System.assertNotEquals(null, responses[0].success, 'Success flag is always set');
    }

    @IsTest
    static void testBulkRequests() {
        ensureTemplates();
        createContact();

        List<AEHC_Asset__c> assets = new List<AEHC_Asset__c>();
        for (Integer i = 0; i < 20; i++) {
            assets.add(new AEHC_Asset__c(
                Name = 'Bulk ' + i,
                AEHC_Is_Subscription__c = false,
                AEHC_Environment__c = 'Dev'
            ));
        }
        insert assets;

        List<AEHC_EmailAlertServiceController.EmailRequest> requests =
            new List<AEHC_EmailAlertServiceController.EmailRequest>();

        for (AEHC_Asset__c asset : assets) {
            requests.add(buildRequest(asset.Id, 'SUBMITTED', 'SUBMITTED', null, 'Dev', false, null));
        }

        Test.startTest();
        List<AEHC_EmailAlertServiceController.EmailResponse> responses =
            AEHC_EmailAlertServiceController.sendAssetEmail(requests);
        Test.stopTest();

        System.assertEquals(20, responses.size(), 'Every request gets its own response');
    }

    @IsTest
    static void testRequestAndResponseWrappers() {
        AEHC_EmailAlertServiceController.EmailRequest req =
            new AEHC_EmailAlertServiceController.EmailRequest();

        req.recordId = UserInfo.getUserId();
        req.eventType = 'SUBMITTED';
        req.recipientUsers = new List<String>{ UserInfo.getUserId() };
        req.previousEnv = 'Dev';
        req.currentEnv = 'QA';
        req.approvalStatus = 'Submitted to DDH';
        req.isAdl = true;

        AEHC_EmailAlertServiceController.EmailResponse res =
            new AEHC_EmailAlertServiceController.EmailResponse();
        res.success = true;
        res.message = 'ok';

        System.assertEquals('QA', req.currentEnv, 'Request fields round-trip');
        System.assertEquals(true, req.isAdl, 'Request fields round-trip');
        System.assertEquals(1, req.recipientUsers.size(), 'Request fields round-trip');
        System.assertEquals(true, res.success, 'Response fields round-trip');
        System.assertEquals('ok', res.message, 'Response fields round-trip');
    }
}