/**
 * @author Asif Ahmad
 * @date 20May2026
 * @description to behave as Controller of LWC, where it provides Management of an Application (Search, Creation)
*/
public class AEHC_ManageApplicationCtrl {
    
    @AuraEnabled
    public static Map<String, Object> searchApplication(String applicationIdentifier) {
        // AEHC_AccountCreationRequest__e evt =new AEHC_AccountCreationRequest__e(AEHC_AssetId__c='123',AEHC_Asset_Name__c='test123');
        // EventBus.publish(evt);
        Map<String, Object> response = new Map<String, Object>();
        Map<String, Object> data = new Map<String, Object>();
        try {
            
            // prepare filter
            List<String> filters = new List<String>();
            filters.add('RecordType.DeveloperName = \'' + AEHC_Constant.RECORDTYPENAME_ASSET_APPLICATION + '\'');
            filters.add('(Name LIKE \'%' + applicationIdentifier + '%\' OR AEHC_Application_Id__c LIKE \'%' + applicationIdentifier + '%\')');
            filters.add('AEHC_Is_Active__c = true');
            
            String filterString = String.join(filters, ' AND ');
            
            // look into Salesforce
            String query = 'SELECT Id, Name, AEHC_Application_Id__c FROM AEHC_Asset__c WHERE ' + filterString + ' ORDER BY Name ASC LIMIT 10';
            List<AEHC_Asset__c> applications = Database.query(query);
            if(!applications.isEmpty()) {
                response.put('status', 200);
                
                List<AEHC_Utility.LookupField> apps = new List<AEHC_Utility.LookupField>();
                for(AEHC_Asset__c app : applications) {
                    apps.add(new AEHC_Utility.LookupField(app.Id, app.Name, app.AEHC_Application_Id__c, true));
                }
                
                // add apps[] in data
                data.put('isFoundInSalesforce', true);
                data.put('apps', apps);
                
                // add in response
                response.put('data', data);
                return response;
            }
            
            // look into Service Now CMDB 
            
            data.put('isFoundInSalesforce', false);
            
            // make callout to CMDB endpoint
            AEHC_APIHelper.Result result = AEHC_SNOW_ApplicationSearchService.searchApplication(applicationIdentifier);
            
            if(result.statusCode == 200) {
                
                List<ApplicationDetail> apps = new List<ApplicationDetail>();
                for(Object app : (List<Object>)result.data) {
                    Map<String, Object> appData = (Map<String, Object>)app;
                    String apmNumber = AEHC_Utility.getStringFromMap(appData, 'number', '');
                    
                    // App detail
                    ApplicationDetail appDetail = new ApplicationDetail(apmNumber, AEHC_Utility.getStringFromMap(appData, 'u_display_name', ''), apmNumber, false);
                    
                    appDetail.description = AEHC_Utility.getStringFromMap(appData, 'short_description', '');
                    appDetail.dataClassification = AEHC_Utility.getStringFromMap(appData, 'u_data_classification', '');
                    appDetail.CCI = AEHC_Utility.getStringFromMap(appData, 'u_cii', '');
                    appDetail.PHI = AEHC_Utility.getStringFromMap(appData, 'u_phi', '');
                    appDetail.PII = AEHC_Utility.getStringFromMap(appData, 'u_pii', '');
                    appDetail.isSFRecord = false;
                    // Business Owner
                    Map<String, Object> businessOwner = (Map<String, Object>)AEHC_Utility.getValueAsObjectFromMap(appData, 'owned_by', null);
                    if(businessOwner != null) appDetail.businessOwner = new AEHC_Utility.LookupField(AEHC_Utility.getStringFromMap(businessOwner, 'value', ''), null, null, false);
                    
                    // IT Owner
                    Map<String, Object> ITOwner = (Map<String, Object>)AEHC_Utility.getValueAsObjectFromMap(appData, 'it_application_owner', null);
                    if(ITOwner != null) appDetail.ITOwner = new AEHC_Utility.LookupField(AEHC_Utility.getStringFromMap(ITOwner, 'value', ''), null, null, false);
                    
                    // Portfolio
                    Map<String, Object> portfolio = (Map<String, Object>)AEHC_Utility.getValueAsObjectFromMap(appData, 'portfolio', null);
                    if(portfolio != null) appDetail.portfolio = AEHC_Utility.getStringFromMap(portfolio, 'value', '');

                    apps.add(appDetail);
                }

                data.put('apps', apps);
                response.put('status', 200);
                
            } else {
                response.put('status', 404);
                response.put('message', AEHC_Constant.LBL_NO_APP_FOUND);
            }
            // and add data in data map key as apps
            response.put('data', data);
            return response;
            
            
        } catch(Exception e) {
            AEHC_Logger.logException(e, 'Apex', 'AEHC_ManageApplicationCtrl', 'query', null, 'P1', null, null, AEHC_Utility.getCurrentEnvironment());
            response.put('status', 500);
            response.put('message', e.getMessage());
        }
        return response;
    }
    
    @AuraEnabled
    public static Map<String, Object> getApplicationDetail(String appDetailStr) {
        Map<String, Object> result = new Map<String, Object>();
        try {
            ApplicationDetail appDetail = (ApplicationDetail) JSON.deserialize(appDetailStr, ApplicationDetail.class);

            if(AEHC_Utility.isValidRecordId(appDetail.id)) {
                List<String> fields = new List<String>();
                fields.add('Id');
                fields.add('Name');
                fields.add('AEHC_Application_Id__c');
                fields.add('AEHC_Description__c');
                fields.add('AEHC_Data_Classification__c');
                fields.add('AEHC_Portfolio__c');
                fields.add('AEHC_CCI_Confidential_Client_Information__c');
                fields.add('AEHC_PHI_Protected_Health_information__c');
                fields.add('AEHC_PII_Personally_Identifiable_info__c');
                fields.add('AEHC_CMDB_BusinessOwner__c');
                fields.add('AEHC_CMDB_BusinessOwnerEmail__c');
                fields.add('AEHC_CMDB_ITOwner__c');
                fields.add('AEHC_CMDB_ITOwnerEmail__c');
                String query = 'SELECT ' + String.join(fields, ',') + ' FROM AEHC_Asset__c WHERE Id = \'' + appDetail.id + '\' AND AEHC_Is_Active__c = true';
                List<AEHC_Asset__c> apps = Database.query(query);
                
                if(apps.isEmpty()) {
                    result.put('status', 404);
                    return result;
                }
                
                result.put('status', 200);
                
                // populate fields
                AEHC_Asset__c appRec = apps[0];
                
                appDetail.name = appRec.Name;
                appDetail.apmNumber = appRec.AEHC_Application_Id__c;
                appDetail.description = appRec.AEHC_Description__c;
                appDetail.dataClassification = appRec.AEHC_Data_Classification__c;
                appDetail.CCI = appRec.AEHC_CCI_Confidential_Client_Information__c;
                appDetail.PHI = appRec.AEHC_PHI_Protected_Health_information__c;
                appDetail.PII = appRec.AEHC_PII_Personally_Identifiable_info__c;
                appDetail.portfolio = appRec.AEHC_Portfolio__c;
                appDetail.isSFRecord = true;
                
                // get Business Owner and IT Owner from Asset Member
                appDetail.businessOwner = new AEHC_Utility.LookupField(appRec.AEHC_CMDB_BusinessOwnerEmail__c, appRec.AEHC_CMDB_BusinessOwner__c, appRec.AEHC_CMDB_BusinessOwnerEmail__c);
                appDetail.ITOwner = new AEHC_Utility.LookupField(appRec.AEHC_CMDB_ITOwnerEmail__c, appRec.AEHC_CMDB_ITOwner__c, appRec.AEHC_CMDB_ITOwnerEmail__c);
                result.put('data', appDetail);
                return result;
            } 
            
            // fetch from Service Now API,
            appDetail.isSFRecord = false;
            
            // as we have already all the details, just pull Business Owner, IT Owner and Portfolio details
            
            if(appDetail.businessOwner != null) {
                AEHC_APIHelper.Result resultAPI = AEHC_SNOW_ApplicationSearchService.invokeServiceNowAPI(AEHC_Constant.GET, appDetail.businessOwner.id);
                if(resultAPI.statusCode == 200) {
                    Map<String, Object> responseData = (Map<String, Object>)JSON.deserializeUnTyped((String)resultAPI.data);
                    Object businessOwnerObj = AEHC_Utility.getValueAsObjectFromMap(responseData, 'result', null);
                    Map<String, Object> businessOwner;
                    if(businessOwnerObj != null) {
                        List<Object> resultList = (List<Object>) businessOwnerObj;
                        if (!resultList.isEmpty()) {
                            businessOwner = (Map<String, Object>) resultList[0];
                            appDetail.businessOwner.subField = AEHC_Utility.getStringFromMap(businessOwner, 'email', ''); // email
                            appDetail.businessOwner.mainField = AEHC_Utility.getStringFromMap(businessOwner, 'name', ''); // name
                            appDetail.businessOwner.isSFRecord = false;
                        }
                    }
                }
            } else {
                appDetail.businessOwner = new AEHC_Utility.LookupField();
            }
            
            if(appDetail.ITOwner != null) {
                AEHC_APIHelper.Result resultAPI = AEHC_SNOW_ApplicationSearchService.invokeServiceNowAPI(AEHC_Constant.GET, appDetail.ITOwner.id);
                if(resultAPI.statusCode == 200) {
                    Map<String, Object> responseData = (Map<String, Object>)JSON.deserializeUnTyped((String)resultAPI.data);
                    Object ITOwnerObj = AEHC_Utility.getValueAsObjectFromMap(responseData, 'result', null);
                     Map<String, Object> ITOwner;
                    if(ITOwnerObj != null) {
                        List<Object> resultListITOwner = (List<Object>) ITOwnerObj;
                        if (!resultListITOwner.isEmpty()) {
                            ITOwner = (Map<String, Object>) resultListITOwner[0];
                            appDetail.ITOwner.subField = AEHC_Utility.getStringFromMap(ITOwner, 'email', ''); // email
                            appDetail.ITOwner.mainField = AEHC_Utility.getStringFromMap(ITOwner, 'name', ''); // name
                            appDetail.businessOwner.isSFRecord = false;
                        }  
                    }
                }
            } else {
                appDetail.ITOwner = new AEHC_Utility.LookupField();
            }
            
            if(appDetail.portfolio != null) {
                AEHC_APIHelper.Result resultAPI = AEHC_SNOW_ApplicationSearchService.invokeServiceNowAPI(AEHC_Constant.GET, appDetail.portfolio);
                if(resultAPI.statusCode == 200) {
                    Map<String, Object> responseData = (Map<String, Object>)JSON.deserializeUnTyped((String)resultAPI.data);
                    Object portfolioObj = AEHC_Utility.getValueAsObjectFromMap(responseData, 'result', null);
                    Map<String, Object> portfolio;
                    if(portfolioObj != null) {
                        List<Object> resultListportfolio = (List<Object>) portfolioObj;
                        if (!resultListportfolio.isEmpty()) {
                             portfolio = (Map<String, Object>) resultListportfolio[0];
                             appDetail.portfolio = AEHC_Utility.getStringFromMap(portfolio, 'name', '');
                        } else {
                            appDetail.portfolio = '';
                        }  
                    }
                }
            }
            
            // look for User for BO or IT
            List<User> users = [SELECT Id, Email, Name FROM User WHERE (Email =:appDetail.ITOwner.subField OR Email =:appDetail.businessOwner.subField) AND IsActive = true];
            for(User uRec : users) {
                if(uRec.Email == appDetail.ITOwner.subField) appDetail.ITOwner = new AEHC_Utility.LookupField(uRec.Id, uRec.Name, uRec.Email, true);
                else if(uRec.Email == appDetail.businessOwner.subField) appDetail.businessOwner = new AEHC_Utility.LookupField(uRec.Id, uRec.Name, uRec.Email, true);
            }
            
            result.put('status', 200);
            result.put('data', appDetail);
            return result;
            
        } catch(Exception e) {
            AEHC_Logger.logException(e, 'Apex', 'AEHC_ManageApplicationCtrl', 'query', null, 'P1', null, null, AEHC_Utility.getCurrentEnvironment());
            result.put('status', 500);
            result.put('message', e.getMessage());
        }
        return result;
    }
    
    @AuraEnabled
    public static Map<String, Object> createApplication(String payload) {
        Map<String, Object> result = new Map<String, Object>();
        try {
            ApplicationDetail appDetail = (ApplicationDetail) JSON.deserialize(payload, ApplicationDetail.class);
            
            AEHC_Asset__c appRec = new AEHC_Asset__c();
            appRec.AEHC_Is_Active__c = true;
            appRec.Name = appDetail.name;
            appRec.AEHC_Application_Id__c = appDetail.apmNumber;
            appRec.AEHC_Description__c = appDetail.description;
            appRec.AEHC_Data_Classification__c = appDetail.dataClassification;
            appRec.AEHC_Portfolio__c = appDetail.portfolio;
            appRec.AEHC_CCI_Confidential_Client_Information__c = appDetail.CCI; // 15-chars
            appRec.AEHC_PHI_Protected_Health_information__c = appDetail.PHI; // 5-chars
            appRec.AEHC_PII_Personally_Identifiable_info__c = appDetail.PII; // 7-chars
            
            // Business Owner
            appRec.AEHC_CMDB_BusinessOwner__c =  appDetail.businessOwner.mainField;
            appRec.AEHC_CMDB_BusinessOwnerEmail__c =  appDetail.businessOwner.subField;
            
            // IT Owner
            appRec.AEHC_CMDB_ITOwner__c =  appDetail.ITOwner.mainField;
            appRec.AEHC_CMDB_ITOwnerEmail__c =  appDetail.ITOwner.subField;
            
            appRec.RecordTypeId = Schema.SObjectType.AEHC_Asset__c.getRecordTypeInfosByDeveloperName().get(AEHC_Constant.RECORDTYPENAME_ASSET_APPLICATION).getRecordTypeId();
            Database.SaveResult insertRes = Database.insert(appRec, false);
            
            // check resullt
            if(!insertRes.isSuccess()) {
                List<String> errorArr = new List<String>();
                for(Database.Error err : insertRes.getErrors()) errorArr.add((err.fields.size() > 0 ? err.fields + ':' : '') +  err.getMessage());
                String insertMsg = String.join(errorArr, ';');
                
                AEHC_Logger.logError(insertMsg,'Apex','AEHC_ManageApplicationCtrl.createApplication','Create',null,'P2','DML', new Map<String, Object>{'payload' => payload},AEHC_Utility.getCurrentEnvironment());
                
                result.put('status', 400);
                result.put('message', insertMsg);
                return result;
            }
            
            String appRecordId = insertRes.getId();
            Map<String, Object> data = new Map<String, Object>();
            data.put('Id', appRecordId);
            
            // add current User in App according to the Role
            List<AEHC_AssetMember__c> assetMembers = new List<AEHC_AssetMember__c>();
            
            List<String> userIds = new List<String>();
            if(appDetail.businessOwner.isSFRecord) {
                userIds.add(appDetail.businessOwner.id);
                assetMembers.add(AEHC_Utility.addUserInAsset(appRecordId, appDetail.businessOwner.id, AEHC_Constant.ROLE_BUSINESS_OWNER, false));
            }
            if(appDetail.ITOwner.isSFRecord) {
                userIds.add(appDetail.ITOwner.id);
                assetMembers.add(AEHC_Utility.addUserInAsset(appRecordId, appDetail.ITOwner.id, AEHC_Constant.ROLE_IT_OWNER, false));
            }
            String currUserId = UserInfo.getUserId();
            if(!userIds.contains(currUserId)) {
                User uRec = [SELECT Id, AEHC_User_Persona__c FROM User WHERE Id = :currUserId];
                String memberRole = uRec.AEHC_User_Persona__c == AEHC_Constant.ROLE_DEVELOPER ? AEHC_Constant.ROLE_DEVELOPER : AEHC_Constant.ROLE_BUSINESS_OWNER;
                assetMembers.add(AEHC_Utility.addUserInAsset(appRecordId, currUserId, memberRole, false));
            }
            
            if(!assetMembers.isEmpty()) AEHC_Utility.upsertRecs(assetMembers);
            
            result.put('status', 200);
            result.put('data', data);
            result.put('message', AEHC_Constant.LBL_APP_CREATE_SUCCESS);
            return result;
            
        } catch(Exception e) {
            AEHC_Logger.logException(e, 'Apex', 'AEHC_ManageApplicationCtrl', 'query', null, 'P1', null, null, 'Dev');
            result.put('status', 500);
            result.put('message', e.getMessage());
        }
        return result;
    } 
    
    public class ApplicationDetail {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String apmNumber;
        @AuraEnabled public String description;
        @AuraEnabled public String dataClassification;
        @AuraEnabled public AEHC_Utility.LookupField businessOwner;
        @AuraEnabled public AEHC_Utility.LookupField ITOwner;
        @AuraEnabled public String portfolio;
        @AuraEnabled public String CCI;
        @AuraEnabled public String PHI;
        @AuraEnabled public String PII;
        @AuraEnabled public Boolean isSFRecord;
        
        public ApplicationDetail() {}
        
        public ApplicationDetail(String id, String name, String apmNumber, Boolean isSFRecord) {
            this.id = id;
            this.name = name;
            this.apmNumber = apmNumber;
            this.isSFRecord = isSFRecord;
        }
    }

}