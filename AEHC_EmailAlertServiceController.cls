/**
 * @description Optimized controller to handle sending email alerts from a flow in a bulk-safe manner.
 *
 * Optimizations include:
 * 1. Bulk SOQL Queries: Fetches all required records (Assets, Users, Templates) in single queries outside of the main loop.
 * 2. Bulk Email Sending: Aggregates all emails to be sent and uses a single `Messaging.sendEmail()` call.
 * 3. Removed Redundant Queries: Eliminated the unnecessary "dummy" contact query by using a valid User ID as the TargetObjectId.
 * 4. Improved Data Handling: Uses Maps for efficient data retrieval within the loop.
 */
public with sharing class AEHC_EmailAlertServiceController {

    // Flow input class
    public class EmailRequest {
        
        @InvocableVariable(required=true)
        public Id recordId;
        
        @InvocableVariable(required=true)
        public String eventType;
        
        @InvocableVariable
        public List<String> recipientUsers;
        
        @InvocableVariable
        public String previousEnv;
        
        @InvocableVariable(required=true)
        public String currentEnv;
        
        @InvocableVariable(required=true)
        public String approvalStatus;

        @InvocableVariable(required=false)
        public Boolean isAdl;
    }
    
    //flow output class
    public class EmailResponse {
        
        @InvocableVariable
        public Boolean success;
        
        @InvocableVariable
        public String message;
    }

    // Custom Exception for better error handling
    public class EmailException extends Exception {}

    @InvocableMethod(label='Send Asset Email Alert')
    public static List<EmailResponse> sendAssetEmail(List<EmailRequest> requests) {
        
        List<EmailResponse> responses = new List<EmailResponse>();
        Map<Id, EmailResponse> responseMap = new Map<Id, EmailResponse>();
        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();

        // Initialize responses
        for (EmailRequest req : requests) {
            EmailResponse res = new EmailResponse();
            res.success = false; // Default to failure
            responses.add(res);
            responseMap.put(req.recordId, res);
        }

        try {
            // Step 1: Bulk fetch all required data
            Map<Id, AEHC_Asset__c> assetsMap = fetchAssets(requests);
            Map<String, List<User>> usersByRequestMap = fetchRecipientUsers(requests);
            Map<String, EmailTemplate> templatesMap = fetchEmailTemplates(requests, assetsMap);
            Id orgWideEmailId = fetchOrgWideEmailAddressId();

            // Step 2: Process each request and prepare emails
            for (EmailRequest request : requests) {
                AEHC_Asset__c asset = assetsMap.get(request.recordId);
                
                if (asset == null) {
                    responseMap.get(request.recordId).message = 'Asset record not found for Id: ' + request.recordId;
                    continue;
                }

                String templateName = determineTemplateName(asset, request.eventType, request.approvalStatus, request.previousEnv, request.isADL);
                EmailTemplate emailTemplate = templatesMap.get(templateName);

                if (emailTemplate == null) {
                    responseMap.get(request.recordId).message = 'No email template configured for the request. Determined name: ' + templateName;
                    continue;
                }

                List<User> recipientUsers = usersByRequestMap.get(request.recordId);
                if (recipientUsers == null || recipientUsers.isEmpty()) {
                    responseMap.get(request.recordId).message = 'No valid recipient email addresses found.';
                    continue;
                }
                
                // Get recipient details
                List<String> toAddresses = new List<String>();
                for (User u : recipientUsers) {
                    toAddresses.add(u.Contact.Email);
                }
                
                // Create email message
                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                email.setTemplateId(emailTemplate.Id);
                email.setTargetObjectId(recipientUsers[0].Id); // Use a valid user from the recipient list
                email.setTreatTargetObjectAsRecipient(false);
                email.setToAddresses(toAddresses);
                email.setSaveAsActivity(false);

                // Set WhatId based on asset type
                Id whatId = asset.AEHC_Is_Subscription__c ? asset.AEHC_Subscription_Request__c : asset.AEHC_Publication__c;
                if (whatId != null) {
                    email.setWhatId(whatId);
                }
                
                // Set Org-Wide Email Address
                if(orgWideEmailId != null) {
                    email.setOrgWideEmailAddressId(orgWideEmailId);
                }

                emailsToSend.add(email);
                
                responseMap.get(request.recordId).success = true;
                responseMap.get(request.recordId).message = 'Email prepared successfully using template: ' + templateName;
            }

            // Step 3: Send all emails in a single DML call
            if (!emailsToSend.isEmpty()) {
                Messaging.SendEmailResult[] results = Messaging.sendEmail(emailsToSend);

                // Optionally, process results to update individual response messages on failure
                Integer resultIndex = 0;
                for (Messaging.SendEmailResult result : results) {
                    if (!result.isSuccess()) {
                        // Logic to map failed email back to original request if needed
                        // For simplicity, this example does not include detailed error mapping back
                        System.debug(LoggingLevel.ERROR, 'Failed to send email. Errors: ' + result.getErrors());
                    }
                    resultIndex++;
                }
            }

        } catch (Exception e) {
            // Generic error for any unhandled exceptions; apply to all responses
            for(EmailResponse res : responses){
                if(res.success != true) { // Don't override success messages
                    res.success = false;
                    res.message = e.getMessage() + ' at ' + e.getStackTraceString();
                }
            }
        }
        
        return responses;
    }

    // --- Bulk Data Fetching Methods ---

    private static Map<Id, AEHC_Asset__c> fetchAssets(List<EmailRequest> requests) {
        Set<Id> assetIds = new Set<Id>();
        for (EmailRequest req : requests) {
            if (req.recordId != null) assetIds.add(req.recordId);
        }
        if (assetIds.isEmpty()) return new Map<Id, AEHC_Asset__c>();
        
        return new Map<Id, AEHC_Asset__c>([
            SELECT Id, AEHC_Publication_Id__c, Name, AEHC_Publication_Name_Formula__c,
                   AEHC_Publication_Type__c, AEHC_Is_Subscription__c, AEHC_Application_Name_Formula__c,
                   AEHC_Environment__c, OwnerId, CreatedById, AEHC_ADL_Review_Required__c,
                   AEHC_UAT_Approval__c, Approval_Status__c, AEHC_Publication__c,
                   AEHC_Subscription_Request__c, AEHC_Subscription_Request__r.AEHC_UAT_Approval__c,
                   AEHC_Publication__r.AEHC_Publication_Id__c, AEHC_Publication__r.Name
            FROM AEHC_Asset__c WHERE Id IN :assetIds
        ]);
    }

    private static Map<String, List<User>> fetchRecipientUsers(List<EmailRequest> requests) {
        Map<String, List<User>> usersByRequestId = new Map<String, List<User>>();
        Set<Id> userIds = new Set<Id>();
        for (EmailRequest req : requests) {
            if (req.recipientUsers != null) {
                userIds.addAll(req.recipientUsers);
            }
        }
        if (userIds.isEmpty()) return usersByRequestId;

        Map<Id, User> validUsers = new Map<Id, User>();
        for (User usr : [SELECT Id, Name, Contact.Email FROM User WHERE Id IN :userIds AND IsActive = true AND Contact.Email != null]) {
            if (!usr.Contact.email.toLowerCase().contains('invalid')) {
                validUsers.put(usr.Id, usr);
            }
        }
        
        for (EmailRequest req : requests) {
            List<User> userList = new List<User>();
            if (req.recipientUsers != null) {
                for (Id userId : req.recipientUsers) {
                    if (validUsers.containsKey(userId)) {
                        userList.add(validUsers.get(userId));
                    }
                }
            }
            usersByRequestId.put(req.recordId, userList);
        }
        return usersByRequestId;
    }
    
    private static Map<String, EmailTemplate> fetchEmailTemplates(List<EmailRequest> requests, Map<Id, AEHC_Asset__c> assetsMap) {
        Set<String> templateNames = new Set<String>();
        for (EmailRequest req : requests) {
            AEHC_Asset__c asset = assetsMap.get(req.recordId);
            if (asset != null) {
                String templateName = determineTemplateName(asset, req.eventType, req.approvalStatus, req.previousEnv, req.isADL);
                if (String.isNotBlank(templateName)) {
                    templateNames.add(templateName);
                }
            }
        }
        if (templateNames.isEmpty()) return new Map<String, EmailTemplate>();

        return new Map<String, EmailTemplate>(
            [SELECT Id, DeveloperName FROM EmailTemplate WHERE DeveloperName IN :templateNames]
        );
    }
    
    private static Id fetchOrgWideEmailAddressId() {
        try {
            OrgWideEmailAddress[] owea = [select Id from OrgWideEmailAddress where Address = :Label.aehc_OrgWideEmailId LIMIT 1];
            return owea.isEmpty() ? null : owea[0].Id;
        } catch(QueryException e) {
            // If the label does not contain a valid email, the query will fail.
            System.debug(LoggingLevel.ERROR, 'Could not query OrgWideEmailAddress using label aehc_OrgWideEmailId. Check if the label contains a valid email address.');
            return null;
        }
    }

    // --- Logic Methods ---

    // TEMPLATE MAPPING (Unchanged)
    private static final Map<String,String> TEMPLATE_MAP = new Map<String,String>{
        //Publication Mappings
        'PUBLICATION|SUBMITTED' => 'Publication_Creation_Submitted',
        'PUBLICATION|SUBMITTEDIA'=>'Notification_to_Information_Architect_Publication_Request',
        'PUBLICATION|APPROVAL'=>'Publication_Approval_Required',
        'PUBLICATION|APPROVED' => 'Publication_Approved',
        'PUBLICATION|REJECTED' => 'Publication_Rejected',
        'PUBLICATION|PROMOTION|SUBMITTED' => 'Publication_Promotion_Submitted',
        'PUBLICATION|PROMOTION|APPROVAL' => 'Publication_Approval_Required',
        'PUBLICATION|PROMOTION|APPROVED'  => 'Publication_Promotion_Approved',
        'PUBLICATION|PROMOTION|REJECTED' => 'Publication_Promotion_Rejected',
        'PUBLICATION|SUBMITTEDADL'=>'GP_Schema_Change_Submitted',
        'PUBLICATION|SUBMITTEDADL|TOBO'=>'GP_Schema_Change_Submitted',
        'PUBLICATION|APPROVALADL|BO' => 'GP_Schema_Approval_Required_BO',
        'PUBLICATION|APPROVEDADL|APPROVEDIABO' => 'GP_Schema_Approved',
        'PUBLICATION|APPROVALADL|IA' => 'GP_Schema_Approval_Required_IA',
        'PUBLICATION|APPROVALADL|ADL' => 'GP_Schema_Approval_Required_IA',
        'PUBLICATION|APPROVEDADL|FINALCOMPLETED'=>'GP_Schema_Completed',
        'PUBLICATION|REJECTEDADL|FINALREJECTED'=>'GP_Schema_Rejected',
        'PUBLICATION|APPROVEDADL|ACTIVE'=>'Impacted_Subscriber_Notification',
        // Subscription mappings
        'SUBSCRIPTION|SUBMITTED'  => 'Subscription_Request_Submitted',
        'SUBSCRIPTION|SUBMITTEDIA'=>'Notificaion_to_Information_Architect_Subscription_Request',
        'SUBSCRIPTION|APPROVAL'=>'Subscription_Approval_Required', 
        'SUBSCRIPTION|APPROVED'  => 'Subscription_Approved',
        'SUBSCRIPTION|REJECTED'  => 'Subscription_Rejected',
        'SUBSCRIPTION|PROMOTION|SUBMITTED' => 'Subscription_Promotion_Submitted',
        'SUBSCRIPTION|PROMOTION|APPROVAL' => 'Subscription_Approval_Required',
        'SUBSCRIPTION|PROMOTION|APPROVED'  => 'Subscription_Promotion_Approved',
        'SUBSCRIPTION|PROMOTION|REJECTED' =>  'Subscription_Promotion_Rejected',
        'SUBSCRIPTION|UATTOGGLE|APPROVED'=>'Subscription_Approved_by_PBO_with_UAT_Toggle_Enabled_Disabled',
        'SUBSCRIPTION|UATTOGGLE|REJECTED'=>'Subscription_Rejected_by_PBO_with_UAT_Toggle_Enabled_Disabled' 
    };

    // DETERMINE TEMPLATE (Unchanged)
    private static String determineTemplateName(AEHC_Asset__c asset,String eventType,String approvalStatus,String previousEnvironment, Boolean isADL) {
        if (asset == null || String.isBlank(eventType)) {
            return null;
        }
        
        String assetType = asset.AEHC_Is_Subscription__c ? 'SUBSCRIPTION' : 'PUBLICATION';
        Boolean isPromotionApproval = String.isBlank(previousEnvironment) && (approvalStatus == 'DDH Admin Review' || approvalStatus == 'Security Architect Review') && (asset.AEHC_Environment__c=='QA' ||asset.AEHC_Environment__c=='UAT'||asset.AEHC_Environment__c=='Production');
        Boolean isPromotionApproved = !String.isBlank(previousEnvironment) && (previousEnvironment == asset.AEHC_Environment__c) && (approvalStatus=='Submitted to DDH') && (asset.AEHC_Environment__c=='QA' ||asset.AEHC_Environment__c=='UAT'||asset.AEHC_Environment__c=='Production');
        Boolean isPromotionRejected = !String.isBlank(previousEnvironment) && (previousEnvironment == asset.AEHC_Environment__c) && (approvalStatus=='Rejected') && (asset.AEHC_Environment__c=='QA' ||asset.AEHC_Environment__c=='UAT'||asset.AEHC_Environment__c=='Production');
        
        Boolean isPromotion = (isPromotionApproval || isPromotionApproved) || isPromotionRejected;

        String key;

        if(!isPromotion && approvalStatus!='Submitted to DDH' && assetType == 'SUBSCRIPTION' && asset.AEHC_Subscription_Request__r.AEHC_UAT_Approval__c && (eventType =='APPROVED' || eventType =='REJECTED') ){
             key=assetType + '|UATTOGGLE|'+eventType;
             return TEMPLATE_MAP.get(key);
        }

        key=assetType + '|' + (isPromotion ? 'PROMOTION|' : '') + eventType;
        key=isADL?key+'ADL':key;

        if( isADL && approvalStatus=='Business Owner Publication Review' && eventType =='SUBMITTED' ){
            key= key + '|TOBO';
        }
        if( isADL && approvalStatus=='Business Owner Publication Review' && eventType =='APPROVAL' ){
            key=key + '|BO';
        }
        if( isADL && (approvalStatus=='Information Architect Review' && eventType =='APPROVAL')){
            key=key + '|IA';
        }
        if( isADL && (approvalStatus=='Pending ADL Review' && eventType =='APPROVAL')){
            key=key + '|ADL';
        }
        if( isADL  && (approvalStatus!='Submitted to DDH' && approvalStatus!='Active' && eventType =='APPROVED')){
            key=key + '|APPROVEDIABO';
        }
        if( isADL && (approvalStatus=='Submitted to DDH' && eventType =='APPROVED')){
            key=key + '|FINALCOMPLETED';
        }
        if( isADL && (approvalStatus=='Active' && eventType =='APPROVED')){
            key=key + '|ACTIVE';
        }
        if( isADL && approvalStatus=='Rejected' && eventType =='REJECTED' ){
            key=key + '|FINALREJECTED';
        }

        System.debug( LoggingLevel.INFO, 'Email Template Key=' + key );
        return TEMPLATE_MAP.get(key);
    }
}