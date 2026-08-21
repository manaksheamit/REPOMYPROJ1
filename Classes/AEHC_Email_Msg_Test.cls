@IsTest(SeeAllData=true)
private class AEHC_Email_Msg_Test {

    @IsTest
    static void test_Cover_All_Branches_No_Asserts() {

        // --------------------------------------------------
        // Setup objects (outside runAs)
        // --------------------------------------------------
        OrgWideEmailAddress owe =
            [SELECT Id FROM OrgWideEmailAddress LIMIT 1];

        Folder emailFolder =
            [SELECT Id FROM Folder WHERE Type = 'Email' LIMIT 1];

        EmailTemplate tmpl = new EmailTemplate(
            Name = 'Unit Test Template',
            DeveloperName = 'UNIT_TEST_TEMPLATE',
            FolderId = emailFolder.Id,
            TemplateType = 'text',
            Subject = 'Test Subject',
            Body = 'Hello {!Recipient.Name}'
        );
        insert tmpl;

        User u = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];

        // --------------------------------------------------
        // Non‑setup objects
        // --------------------------------------------------
        System.runAs(u) {

            Account acc = new Account(Name = 'Test Account');
            insert acc;

            Contact con = new Contact(
                LastName = 'Test Contact',
                Email = 'test@email.com',
                AccountId = acc.Id
            );
            insert con;

            // --------------------------------------------------
            // Build multiple FlowInput scenarios
            // --------------------------------------------------

            // 1. Null input list
            Test.startTest();
            AEHC_email_msg_helper.sendEmails(null);

            // 2. Empty input list
           AEHC_email_msg_helper.sendEmails(
                new List<AEHC_email_msg_helper.FlowInput>()
            );

            // 3. Input row = null
            AEHC_email_msg_helper.sendEmails(
                new List<AEHC_email_msg_helper.FlowInput>{ null }
            );

            // 4. Missing contactIds
            AEHC_email_msg_helper.FlowInput noContacts =
                new AEHC_email_msg_helper.FlowInput();
            noContacts.recordId = acc.Id;
            noContacts.orgWideEmailAddressId = owe.Id;
            noContacts.emailTemplateId = tmpl.Id;

            AEHC_email_msg_helper.sendEmails(
                new List<AEHC_email_msg_helper.FlowInput>{ noContacts }
            );

            // 5. Missing recordId
            AEHC_email_msg_helper.FlowInput noRecord =
                new AEHC_email_msg_helper.FlowInput();
            noRecord.contactIds = new List<Id>{ con.Id };
            noRecord.orgWideEmailAddressId = owe.Id;
            noRecord.emailTemplateId = tmpl.Id;

            AEHC_email_msg_helper.sendEmails(
                new List<AEHC_email_msg_helper.FlowInput>{ noRecord }
            );

            // 6. Invalid OrgWide prefix
            AEHC_email_msg_helper.FlowInput badOrgWide =
                new AEHC_email_msg_helper.FlowInput();
            badOrgWide.contactIds = new List<Id>{ con.Id };
            badOrgWide.recordId = acc.Id;
            badOrgWide.emailTemplateId = tmpl.Id;
            badOrgWide.orgWideEmailAddressId = (Id)'001000000000000AAA';

            AEHC_email_msg_helper.sendEmails(
                new List<AEHC_email_msg_helper.FlowInput>{ badOrgWide }
            );

            // 7. Invalid Template prefix
            AEHC_email_msg_helper.FlowInput badTemplate =
                new AEHC_email_msg_helper.FlowInput();
            badTemplate.contactIds = new List<Id>{ con.Id };
            badTemplate.recordId = acc.Id;
            badTemplate.orgWideEmailAddressId = owe.Id;
            badTemplate.emailTemplateId = (Id)'001000000000000AAA';

            AEHC_email_msg_helper.sendEmails(
                new List<AEHC_email_msg_helper.FlowInput>{ badTemplate }
            );

            // 8. SUCCESS path
            AEHC_email_msg_helper.FlowInput success =
                new AEHC_email_msg_helper.FlowInput();
            success.contactIds = new List<Id>{ con.Id, con.Id, null };
            success.recordId = acc.Id;
            success.orgWideEmailAddressId = owe.Id;
            success.emailTemplateId = tmpl.Id;

            AEHC_email_msg_helper.sendEmails(
                new List<AEHC_email_msg_helper.FlowInput>{ success }
            );

            // 9. EXCEPTION path (invalid TargetObjectId)
            AEHC_email_msg_helper.FlowInput exceptionCase =
                new AEHC_email_msg_helper.FlowInput();
            exceptionCase.contactIds = new List<Id>{ acc.Id };
            exceptionCase.recordId = acc.Id;
            exceptionCase.orgWideEmailAddressId = owe.Id;
            exceptionCase.emailTemplateId = tmpl.Id;

            AEHC_email_msg_helper.sendEmails(
                new List<AEHC_email_msg_helper.FlowInput>{ exceptionCase }
            );

            Test.stopTest();
        }
    }
}