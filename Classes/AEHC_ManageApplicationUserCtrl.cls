/**
 * @description Controller for managing Asset Member records
 * @author Asif Ahmad
 * @date 1Jun2026
 */
public without sharing class AEHC_ManageApplicationUserCtrl {
    
    /**
     * @description Get all asset members for a given asset
     * @param applicationId The Application Record Id
     * @return List of Asset Member records
     */
    @AuraEnabled
    public static Map<String, Object> getMembers(String applicationId) {
        Map<String, Object> response = new Map<String, Object>();
        try {
            
            List<AEHC_AssetMember__c> assetMembers = [
                SELECT Id, AEHC_User__c, AEHC_User__r.Name, AEHC_User__r.Email, 
                       AEHC_Role__c, AEHC_Asset__c
                FROM AEHC_AssetMember__c
                WHERE AEHC_Asset__c = :applicationId
                ORDER BY AEHC_User__r.Name ASC
            ];
            
            if(assetMembers.isEmpty()) {
                response.put('status', 404);
                return response;
            }
            
            response.put('status', 200);
            response.put('data', assetMembers);
            return response;
            
        } catch(Exception e) {
            AEHC_Logger.logException(e, 'Apex', 'AEHC_ManageApplicationUserCtrl.getMembers', 'query', null, 'P1', null, null, AEHC_Utility.getCurrentEnvironment());
            response.put('status', 500);
            response.put('message', e.getMessage());
        }
        return response;
    }
    
    /**
     * @description Save (insert or update) an asset member record
     * @param assetMember The Asset Member record to save
     * @return The saved Asset Member record
     */
    @AuraEnabled
    public static Map<String, Object> upsertAssetMember(String payload) {
        Map<String, Object> response = new Map<String, Object>();
        try {
            
            // process payload
            Map<String, Object> amDetail = (Map<String, Object>)JSON.deserializeUntyped(payload);
            
            String userId = AEHC_Utility.getStringFromMap(amDetail, 'userId', null);
            String role = AEHC_Utility.getStringFromMap(amDetail, 'role', null);
            String assetId = AEHC_Utility.getStringFromMap(amDetail, 'assetId', null);
            String recordId = AEHC_Utility.getStringFromMap(amDetail, 'recordId', null);
            
            if(String.isEmpty(recordId)) {
                // check duplicate
                List<AEHC_AssetMember__c> amRecs = [
                    SELECT Id, AEHC_Role__c
                    FROM AEHC_AssetMember__c
                    WHERE AEHC_Asset__c = :assetId
                    AND AEHC_User__c = :userId
                    LIMIT 1
                ];
                
                if(!amRecs.isEmpty()) {
                    response.put('status', 400);
                    response.put('message', 'User is already member of the application with Role: ' + amRecs[0].AEHC_Role__c);
                    return response;
                }
            } else {
                
                // if we are updating same rec, and if we are changing last:Business Owner to something else it should warn
                List<AEHC_AssetMember__c> otherBOs = [SELECT Id FROM AEHC_AssetMember__c WHERE 
                                                      Id != :recordId AND 
                                                      AEHC_Role__c = :AEHC_Constant.ROLE_BUSINESS_OWNER AND 
                                                      AEHC_Asset__c = :assetId
                                                     ];
                
                if(otherBOs.isEmpty()) {
                    response.put('status', 400);
                    response.put('message', 'At least one ' + AEHC_Constant.ROLE_BUSINESS_OWNER + ' must exist in the application');
                    return response;
                }
            }
            
            // prepare SObject
            AEHC_AssetMember__c assetMember = AEHC_Utility.addUserInAsset(assetId, userId, role, false);
            
            // populate recordId for upsert operation
            assetMember.Id = recordId;
            
            // upsert
            AEHC_Utility.upsertRecs(new List<AEHC_AssetMember__c>{assetMember});
            
            response.put('status', 200);
            response.put('message', recordId == null ? 'Member added successfully' : 'Membership updated successfully');
            
        } catch(Exception e) {
            AEHC_Logger.logException(e, 'Apex', 'AEHC_ManageApplicationUserCtrl.upsertAssetMember', 'query', null, 'P1', null, null, AEHC_Utility.getCurrentEnvironment());
            response.put('status', 500);
            response.put('message', e.getMessage());
        }
        return response;
    }
    
    /**
     * @description Delete an asset member record
     * @param recordId The Asset Member Id to delete
     */
    @AuraEnabled
    public static Map<String, Object> deleteAssetMember(String recordId) {
        Map<String, Object> response = new Map<String, Object>();
        try {
            
            // check business owner
            AEHC_AssetMember__c memberToDelete = [
                SELECT Id, AEHC_Role__c, AEHC_Asset__c
                FROM AEHC_AssetMember__c
                WHERE Id = :recordId
                LIMIT 1
            ];
            
            if(memberToDelete.AEHC_Role__c == AEHC_Constant.ROLE_BUSINESS_OWNER) {
                List<AEHC_AssetMember__c> otherBOs = [SELECT Id FROM AEHC_AssetMember__c WHERE 
                                                      Id != :recordId AND 
                                                      AEHC_Role__c = :AEHC_Constant.ROLE_BUSINESS_OWNER AND 
                                                      AEHC_Asset__c = :memberToDelete.AEHC_Asset__c
                                                     ];
                
                if(otherBOs.isEmpty()) {
                    response.put('status', 400);
                    response.put('message', 'At least one ' + AEHC_Constant.ROLE_BUSINESS_OWNER + ' must exist in the application');
                    return response;
                }
            }
            
            delete memberToDelete;
            
            response.put('status', 200);
            response.put('message', 'Member deleted successfully');
            
        } catch(Exception e) {
            AEHC_Logger.logException(e, 'Apex', 'AEHC_ManageApplicationUserCtrl.deleteAssetMember', 'query', null, 'P1', null, null, AEHC_Utility.getCurrentEnvironment());
            response.put('status', 500);
            response.put('message', e.getMessage());
        }
        return response;
    }
    
    /**
     * @description Search for users based on search term
     * @param searchTerm The search string to find users
     * @param recordLimit Maximum number of records to return
     * @return List of user records matching the search criteria
     */
    @AuraEnabled
    public static Map<String, Object> searchUsers(String searchTerm) {
        Map<String, Object> response = new Map<String, Object>();
        Map<String, Object> data = new Map<String, Object>();
        try {
            searchTerm = String.escapeSingleQuotes(searchTerm.trim());
            
            // prepare filter
            List<String> filters = new List<String>();
            filters.add('Profile.Name = \'' + AEHC_Constant.PROFILE_EXTERNAL_IDENTITY + '\'');
            filters.add('(Name LIKE \'%' + searchTerm + '%\' OR Email LIKE \'%' + searchTerm + '%\')');
            filters.add('IsActive = true');
            
            String filterString = String.join(filters, ' AND ');
            
            // preepare query
            String query = 'SELECT Id, Name, Email FROM User WHERE ' + filterString + ' ORDER BY Name ASC LIMIT 5';
            List<User> userRecs = Database.query(query);
            
            // prepare response in wrapper
            if(!userRecs.isEmpty()) {
                response.put('status', 200);
                
                // populate wrapper
                List<AEHC_Utility.LookupField> users = new List<AEHC_Utility.LookupField>();
                for(User uRec : userRecs) {
                    users.add(new AEHC_Utility.LookupField(uRec.Id, uRec.Name, uRec.Email));
                }
                
                // add in response
                response.put('data', users);
                return response;
            }
            
            response.put('status', 404);
            
        } catch(Exception e) {
            AEHC_Logger.logException(e, 'Apex', 'AEHC_ManageApplicationUserCtrl.searchUsers', 'query', null, 'P1', null, null, AEHC_Utility.getCurrentEnvironment());
            response.put('status', 500);
            response.put('message', e.getMessage());
        }
        return response;
    }
    
    /**
     * @description Get role picklist values from the AEHC_Role__c field
     * @return List of picklist options for roles
     */
    /*@AuraEnabled(cacheable=true)
    public static Map<String, Object> getAssetMemberRoles() {
        Map<String, Object> response = new Map<String, Object>();
        try {
            List<Map<String, String>> options = new List<Map<String, String>>();
            
            // Get picklist values from the Role field
            Schema.DescribeFieldResult fieldResult = AEHC_AssetMember__c.AEHC_Role__c.getDescribe();
            List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();
            
            for (Schema.PicklistEntry entry : picklistValues) {
                if (entry.isActive()) {
                    Map<String, String> option = new Map<String, String>();
                    option.put('label', entry.getLabel());
                    option.put('value', entry.getValue());
                    options.add(option);
                }
            }
            response.put('status', 200);
            response.put('data', options);

        } catch(Exception e) {
            AEHC_Logger.logException(e, 'Apex', 'AEHC_ManageApplicationUserCtrl.getAssetMemberRoles', 'query', null, 'P1', null, null, AEHC_Utility.getCurrentEnvironment());
            response.put('status', 500);
            response.put('message', e.getMessage());
        }
        return response;
    } */
    
     
}