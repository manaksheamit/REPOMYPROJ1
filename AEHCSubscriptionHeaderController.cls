/**
 * Controller used by AEHC Subscription Header LWC.
 * Validates whether the currently logged-in user has a specific role
 * on the Application Asset associated with the selected Asset record.
 */
public without sharing class AEHCSubscriptionHeaderController {

    /**
     * Checks if the current user is an Asset Member with the specified role
     * for the Application linked to the provided Asset record.
     *
     * @param recordId  Id of the current AEHC_Asset__c record.
     * @param roleValue Role value to validate against AEHC_Role__c.
     * @return Boolean  True if matching Asset Member record exists; otherwise false.
     */
    @AuraEnabled(cacheable=true)
    public static Boolean hasUserRoleForApplication(Id recordId, String roleValue) {

        // Validate input parameters
        if (recordId == null || String.isBlank(roleValue)) {
            return false;
        }

        // Retrieve the Application lookup from the current Asset
        AEHC_Asset__c assetRecord = [
            SELECT Id, AEHC_Application__c
            FROM AEHC_Asset__c
            WHERE Id = :recordId
            LIMIT 1
        ];

        // Return false if no Application is associated
        if (assetRecord.AEHC_Application__c == null) {
            return false;
        }

        // Check if the current user has the specified role
        // on the Application Asset.
        Integer memberCount = [
            SELECT COUNT()
            FROM AEHC_AssetMember__c
            WHERE AEHC_Role__c = :roleValue
            AND AEHC_User__c = :UserInfo.getUserId()
        ];

        return memberCount > 0;
    }
}