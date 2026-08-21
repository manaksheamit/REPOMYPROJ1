public without sharing class AEHC_Email_Msg_helper {

    public class FlowInput {

        // Recipients: Contact Ids (003...)
        @InvocableVariable(required=true)
        public List<Id> contactIds;

        // WhatId: Subscription__c (or other record) for template merge fields
        @InvocableVariable(required=true)
        public Id recordId;

        // Org Wide Email Address Id (0D2...)
        @InvocableVariable(required=true)
        public Id orgWideEmailAddressId;

        // Email Template Id (00X...)
        @InvocableVariable(required=true)
        public Id emailTemplateId;
    }

    public class FlowOutput {
        @InvocableVariable
        public Boolean success;

        @InvocableVariable
        public String message;

        @InvocableVariable
        public Integer emailsPrepared;
    }

    @InvocableMethod(label='Send Subscription Email to Contacts'
                     description='Sends templated emails to Contact recipients using Org-Wide email, TemplateId and WhatId.')
    public static List<FlowOutput> sendEmails(List<FlowInput> inputs) {

        List<FlowOutput> outputs = new List<FlowOutput>();

        if (inputs == null || inputs.isEmpty()) {
            return outputs;
        }

        // Build all emails first, then send once (best practice)
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        // Create one output record per input row (Flow-friendly)
        for (FlowInput input : inputs) {
            FlowOutput out = new FlowOutput();
            out.success = false;
            out.emailsPrepared = 0;

            try {
                // ----- Validate required inputs -----
                if (input == null) {
                    out.message = 'Input was null.';
                    outputs.add(out);
                    continue;
                }
                if (input.contactIds == null || input.contactIds.isEmpty()) {
                    out.message = 'contactIds is required and cannot be empty.';
                    outputs.add(out);
                    continue;
                }
                if (input.recordId == null) {
                    out.message = 'recordId (WhatId) is required.';
                    outputs.add(out);
                    continue;
                }
                if (input.orgWideEmailAddressId == null) {
                    out.message = 'orgWideEmailAddressId is required.';
                    outputs.add(out);
                    continue;
                }
                if (input.emailTemplateId == null) {
                    out.message = 'emailTemplateId is required.';
                    outputs.add(out);
                    continue;
                }

                // Optional prefix sanity checks (helps catch wrong IDs quickly)
                if (!String.valueOf(input.orgWideEmailAddressId).startsWith('0D2')) {
                    out.message = 'orgWideEmailAddressId does not look like an Org-Wide Email Id (expected prefix 0D2).';
                    outputs.add(out);
                    continue;
                }
                if (!String.valueOf(input.emailTemplateId).startsWith('00X')) {
                    out.message = 'emailTemplateId does not look like an EmailTemplate Id (expected prefix 00X).';
                    outputs.add(out);
                    continue;
                }

                // De-duplicate contacts and remove nulls
                Set<Id> uniqueContacts = new Set<Id>();
                for (Id cId : input.contactIds) {
                    if (cId != null) uniqueContacts.add(cId);
                }

                if (uniqueContacts.isEmpty()) {
                    out.message = 'No valid (non-null) contactIds were provided.';
                    outputs.add(out);
                    continue;
                }

                // ----- Build one email per Contact recipient -----
                for (Id contactId : uniqueContacts) {

                    Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
                    msg.setOrgWideEmailAddressId(input.orgWideEmailAddressId);

                    // Recipient must be Contact/Lead/User for templates
                    msg.setTargetObjectId(contactId);

                    // Record context for merge fields (e.g., Subscription__c fields)
                    msg.setWhatId(input.recordId);

                    msg.setTemplateId(input.emailTemplateId);
                    msg.setSaveAsActivity(false);

                    // Optional: privacy defaults
                    msg.setBccSender(false);
                    msg.setUseSignature(false);

                    emails.add(msg);
                    out.emailsPrepared++;
                }

                out.success = true;
                out.message = 'Prepared ' + out.emailsPrepared + ' email(s).';

            } catch (Exception ex) {
                out.success = false;
                out.message = 'Exception: ' + ex.getMessage();
            }

            outputs.add(out);
        }

        // ----- Send all emails in one call (if any) -----
        if (!emails.isEmpty()) {
            Messaging.SendEmailResult[] results = Messaging.sendEmail(emails, false);


            System.debug('SendEmail results size: ' + results.size());
        }

        return outputs;
    }
}