/**
 * Author: Rushikesh Rajan
 * Description: Handles Correspondence feature for fetching assets, users, and sending emails
 */
public without sharing class AEHC_EmailController {

    // =========================
    // GET ASSETS
    // =========================
   @AuraEnabled(cacheable=true)
    public static List<AssetWrapper> getAssets() {

    List<AssetWrapper> result = new List<AssetWrapper>();

    try {

        // Get assets associated to current user
        Set<Id> assetIds = new Set<Id>();

        for (AEHC_AssetMember__c member : [SELECT AEHC_Asset__c FROM AEHC_AssetMember__c WHERE AEHC_User__c = :UserInfo.getUserId()]) {
            if (member.AEHC_Asset__c != null) {
                assetIds.add(member.AEHC_Asset__c);
            }
        }

        // User is not associated to any asset
        if (assetIds.isEmpty()) {
            return result;
        }

        // Get Applications
        List<AEHC_Asset__c> applications = [SELECT Id, Name FROM AEHC_Asset__c WHERE Id IN :assetIds AND RecordType.DeveloperName = 'AEHC_Application' ORDER BY Name];

        if (applications.isEmpty()) {
            return result;
        }

        // Application Ids
        Set<Id> applicationIds = new Set<Id>();

        for (AEHC_Asset__c app : applications) {
            applicationIds.add(app.Id);
        }

        // Get Publications
        Map<Id, List<AEHC_Asset__c>> publicationsByApp = new Map<Id, List<AEHC_Asset__c>>();

        for (AEHC_Asset__c pub : [SELECT Id, Name, AEHC_Application__c FROM AEHC_Asset__c WHERE RecordType.DeveloperName = 'AEHC_Publication' AND AEHC_Application__c IN :applicationIds ORDER BY Name]) {

            if (pub.AEHC_Application__c == null) {
                continue;
            }

            if (!publicationsByApp.containsKey(pub.AEHC_Application__c)) {
                publicationsByApp.put(pub.AEHC_Application__c, new List<AEHC_Asset__c>());
            }

            publicationsByApp.get(pub.AEHC_Application__c).add(pub);
        }

        // Build flat list
        for (AEHC_Asset__c app : applications) {

            result.add(new AssetWrapper(app.Id, app.Name, 'Application'));

            if (publicationsByApp.containsKey(app.Id)) {

                for (AEHC_Asset__c pub : publicationsByApp.get(app.Id)) {
                    result.add(new AssetWrapper(pub.Id, pub.Name, 'Publication'));
                }
            }
        }

        return result;

    } catch (Exception e) {

        System.debug(LoggingLevel.ERROR, 'AEHC_EmailController.getAssets Error: ' + e.getMessage() + ' Line: ' + e.getLineNumber());

        // Return empty list so UI does not break
        return new List<AssetWrapper>();
    }
}


    // =========================
    // GET ASSOCIATED USERS
    // =========================
    @AuraEnabled(cacheable=true)
public static List<UserWrapper> getAssociatedUsers(Id assetId) {

    if (assetId == null) {
        throw new AuraHandledException('Asset Id is required.');
    }

    try {

        Map<Id, UserWrapper> userMap = new Map<Id, UserWrapper>();

        AEHC_Asset__c asset = [
            SELECT Id,
                   Name,
                   RecordType.DeveloperName,
                   AEHC_Application__c
            FROM AEHC_Asset__c
            WHERE Id = :assetId
            LIMIT 1
        ];

        /*
         * APPLICATION
         */
        if (asset.RecordType.DeveloperName == 'AEHC_Application') {

            // Subscribers
            for (Subscription__c s : [
                SELECT Subscriber__c,
                       Subscriber__r.Name,
                       Subscriber__r.ContactId
                FROM Subscription__c
                WHERE AEHC_Application_Name__c = :assetId
            ]) {
                if (s.Subscriber__c != null &&
                    s.Subscriber__r.ContactId != null) {

                    userMap.put(
                        s.Subscriber__c,
                        new UserWrapper(
                            s.Subscriber__c,
                            s.Subscriber__r.Name,
                            'Subscriber',
                            s.Subscriber__r.ContactId
                        )
                    );
                }
            }

            // Application Asset Members
            for (AEHC_AssetMember__c member : [
                SELECT AEHC_User__c,
                       AEHC_User__r.Name,
                       AEHC_User__r.ContactId
                FROM AEHC_AssetMember__c
                WHERE AEHC_Asset__c = :assetId
            ]) {

                if (member.AEHC_User__c != null &&
                    member.AEHC_User__r.ContactId != null) {

                    userMap.put(
                        member.AEHC_User__c,
                        new UserWrapper(
                            member.AEHC_User__c,
                            member.AEHC_User__r.Name,
                            'Application Member',
                            member.AEHC_User__r.ContactId
                        )
                    );
                }
            }
        }

        /*
         * PUBLICATION
         */
        else if (asset.RecordType.DeveloperName == 'AEHC_Publication') {

            // Publication Subscribers
            for (Subscription__c s : [
                SELECT Subscriber__c,
                       Subscriber__r.Name,
                       Subscriber__r.ContactId
                FROM Subscription__c
                WHERE AEHC_Publication_ID__c = :assetId
            ]) {

                if (s.Subscriber__c != null &&
                    s.Subscriber__r.ContactId != null) {

                    userMap.put(
                        s.Subscriber__c,
                        new UserWrapper(
                            s.Subscriber__c,
                            s.Subscriber__r.Name,
                            'Subscriber',
                            s.Subscriber__r.ContactId
                        )
                    );
                }
            }

            // Application Members
            if (asset.AEHC_Application__c != null) {

                for (AEHC_AssetMember__c member : [
                    SELECT AEHC_User__c,
                           AEHC_User__r.Name,
                           AEHC_User__r.ContactId
                    FROM AEHC_AssetMember__c
                    WHERE AEHC_Asset__c = :asset.AEHC_Application__c
                ]) {

                    if (member.AEHC_User__c != null &&
                        member.AEHC_User__r != null &&
                        member.AEHC_User__r.ContactId != null) {

                        userMap.put(
                            member.AEHC_User__c,
                            new UserWrapper(
                                member.AEHC_User__c,
                                member.AEHC_User__r.Name,
                                'Application Member',
                                member.AEHC_User__r.ContactId
                            )
                        );
                    }
                }
            }
        }

        return new List<UserWrapper>(userMap.values());

    } catch (Exception e) {

        throw new AuraHandledException(
            'Unable to fetch associated users. ' + e.getMessage()
        );
    }
}


    // =========================
    // SEND EMAIL
    // =========================
    @AuraEnabled
@future
public static void sendEmail(List<Id> contactIds, String subject, String body, Id orgWideEmailId, List<String> ccEmails) {

    if (contactIds == null || contactIds.isEmpty()) {
        return;
    }

    try {

        if (orgWideEmailId == null) {
            orgWideEmailId = Label.aehc_OrgWideEmailId;
        }

        Set<String> toEmails = new Set<String>();

Map<Id, Contact> contactMap = new Map<Id, Contact>([
    SELECT Id, Email
    FROM Contact
    WHERE Id IN :contactIds
]);

for (Contact con : contactMap.values()) {
    if (String.isNotBlank(con.Email) && !con.Email.contains('invalid')) {
        toEmails.add(con.Email);
    }
}

if (!toEmails.isEmpty()) {

    Set<String> finalCcEmails = new Set<String>();

    if (ccEmails != null) {
        for (String ccEMail:ccEmails){
            if(!ccEmail.contains('invalid')){
                finalCcEmails.add(ccEMail);
            }
        }
    }

    User currentUser = [
        SELECT Email
        FROM User
        WHERE Id = :UserInfo.getUserId()
        LIMIT 1
    ];

    if (String.isNotBlank(currentUser.Email)) {
        finalCcEmails.add(currentUser.Email);
    }

    Messaging.SingleEmailMessage mail =
        new Messaging.SingleEmailMessage();

    mail.setToAddresses(
        new List<String>(toEmails)
    );

    if (!finalCcEmails.isEmpty()) {
        mail.setCcAddresses(
            new List<String>(finalCcEmails)
        );
    }

    mail.setSubject(subject);
    mail.setHtmlBody(body);
    mail.setSaveAsActivity(false);

    if (orgWideEmailId != null) {
        mail.setOrgWideEmailAddressId(orgWideEmailId);
    }

    Messaging.sendEmail(
        new List<Messaging.SingleEmailMessage>{ mail }
    );
}

    } catch (Exception e) {
        System.debug(
            LoggingLevel.ERROR,
            'Error in sendEmail: ' + e.getMessage()
        );
    }
}


    // =========================
    // WRAPPERS
    // =========================
    public class AssetWrapper {
        @AuraEnabled public Id assetId;
        @AuraEnabled public String name;
        @AuraEnabled public String type;

        public AssetWrapper(Id i, String n, String t) {
            assetId = i;
            name = n;
            type = t;
        }
    }

    public class UserWrapper {
        @AuraEnabled public Id userId;
        @AuraEnabled public String name;
        @AuraEnabled public String role;
        @AuraEnabled public Id contactId;

        public UserWrapper(Id u, String n, String r, Id c) {
            userId = u;
            name = n;
            role = r;
            contactId = c;
        }
    }
}