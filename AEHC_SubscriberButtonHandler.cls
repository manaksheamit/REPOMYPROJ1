public with sharing class AEHC_SubscriberButtonHandler {

    @AuraEnabled(cacheable=true)
    public static Boolean canViewSubscriberButton() {

        Id currentUserId = UserInfo.getUserId();

        Integer recordCount = [
            SELECT COUNT()
            FROM AEHC_AssetMember__c
            WHERE AEHC_User__c = :currentUserId
            AND AEHC_Role__c = 'Enterprise Architect'
        ];

        return recordCount > 0;
    }
}