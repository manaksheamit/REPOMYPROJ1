/*@description Subscription creation controller
*@author Umang Fofariya
* version 1.0
*/
public with sharing class AEHC_SubscriptionController_DP {
    
    // Class-level constants for logging and error handling
    private static final String COMPONENT_TYPE = 'Apex';
    private static final String COMPONENT_NAME = 'AEHC_SubscriptionController_DP';
    private static final String OPERATION_QUERY = 'Query';
    private static final String OPERATION_SUBMIT = 'Submit';
    private static final String SEVERITY_P2 = 'P2'; // High severity for exceptions
    private static final String SEVERITY_P3 = 'P3'; // Normal severity
    private static final String CATEGORY = 'Unknown';
    
    private static final String NAMED_CREDENTIAL_UNITY_CATALOG = 'callout:Unity_Catalog_Detail/';
    private static final String DEFAULT_SCHEMA_ENVIRONMENT = 'dev';
    
    
    public class SubscriptionResponse {
        @AuraEnabled public Id applicationRecordId;
        @AuraEnabled public String applicationId;
        @AuraEnabled public String applicationName;
        @AuraEnabled public Id publicationRecordId;
        @AuraEnabled public String publicationId;
        @AuraEnabled public String publicationName;
        @AuraEnabled public String environment;
        @AuraEnabled public String schemaVersion;
        @AuraEnabled public String schemaName;
        @AuraEnabled public String tableName;
        @AuraEnabled public Boolean showSubscribe;
        @AuraEnabled public Boolean showPromote;
        @AuraEnabled public String description;
        @AuraEnabled public Boolean uatEnabled;
    }
    
    public class SubscriptionEditContextResponse {
        @AuraEnabled public String applicationName;
        @AuraEnabled public String publicationName;
        @AuraEnabled public Id publicationRecordId;
        
        @AuraEnabled public List<String> availableEnvironments;
        @AuraEnabled public String defaultEnvironment;
    }
    
    public class SchemaColumnDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String dataType;
        @AuraEnabled public String description;
        @AuraEnabled public Boolean nullable;
        @AuraEnabled public Integer order;
    }
    
    public class PicklistOptionDTO {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }
    
    public class ScheduleWrapper {
        @AuraEnabled public String schedulerMode;
        @AuraEnabled public String frequency;
        @AuraEnabled public String scheduleTime;
        @AuraEnabled public List<String> weekdays;
        @AuraEnabled public List<String> multiWeekWeeks;
        @AuraEnabled public List<String> multiWeekDays;
        @AuraEnabled public String monthlyDay;
        @AuraEnabled public String oneTimeDate;
        @AuraEnabled public String oneTimeTime;
        @AuraEnabled public String annualDate;
        @AuraEnabled public String scheduleSummary;
        @AuraEnabled public String cronExpression;
    }
    
    public class SubscriptionVersionResponse {
        
        /*
✅ BASIC INFO
*/
        @AuraEnabled public String environment;
        @AuraEnabled public String versionNumber;
        @AuraEnabled public String nextversionNumber;
        @AuraEnabled public Boolean isDraft;
        @AuraEnabled public String consumingApplicationName;
        @AuraEnabled public String consumingApplication;
        
        @AuraEnabled public String applicationName;
        @AuraEnabled public Id applicationId;
        @AuraEnabled public Id applicationRecordId;
        
        @AuraEnabled public String publicationName;
        @AuraEnabled public String publicationId;
        @AuraEnabled public Id publicationRecordId;
        
        @AuraEnabled public String description;
        @AuraEnabled public Id versionRecordId;
        @AuraEnabled public String approvalStatus;
        @AuraEnabled public Boolean versionisActive;
        @AuraEnabled public Boolean uatEnabled;
        
        /*
✅ BUSINESS
*/
        @AuraEnabled public String purposeOfUse;
        @AuraEnabled public Boolean transformationRequired;
        
        /*
✅ SELECTED FIELDS
*/
        @AuraEnabled public List<Object> selectedFieldsJson;
        
        /*
✅ SCHEDULE
*/
        @AuraEnabled public ScheduleWrapper schedule;
        
        /*
✅ DESTINATION
*/
        @AuraEnabled public Map<String, Object> destination;
    }
    
    
    
    @AuraEnabled(cacheable=true)
    public static SubscriptionResponse getSubscriptionDetails(Id recordId) {
        
        SubscriptionResponse res = new SubscriptionResponse();
        
        // Prepare context for logging
        Map<String, Object> context = new Map<String, Object>{
            'method' => 'getSubscriptionDetails',
                'userId' => UserInfo.getUserId(),
                'recordId' => recordId
                };
                    String orgEnv = getCurrentEnvironment();
        
        try {
            // If recordId is provided, fetch from Salesforce
            if (recordId != null) {
                populateFromSalesforce(recordId, res);
            } else {
                // Set default fallback values - Temporary
                setDefaultValues(res);
            }
            
        } catch (QueryException qe) {
            // Handle SOQL/DML exceptions with proper logging
            AEHC_Logger.logException(
                qe,
                COMPONENT_TYPE,
                COMPONENT_NAME,
                OPERATION_QUERY,
                recordId,
                SEVERITY_P2,
                CATEGORY,
                context,
                orgEnv
            );
            throw new AuraHandledException('Database error while retrieving subscription details: ' + qe.getMessage());
            
        } catch (Exception ex) {
            // Handle all other exceptions with proper logging
            AEHC_Logger.logException(
                ex,
                COMPONENT_TYPE,
                COMPONENT_NAME,
                OPERATION_QUERY,
                recordId,
                SEVERITY_P2, // Exception severity
                CATEGORY,
                context,
                orgEnv
            );
            throw new AuraHandledException('Unable to load subscription details: ' + ex.getMessage());
        }
        
        return res;
    }
    
    private static Map<String, Boolean> evaluateButtons(Id publicationId) {
        
        List<AEHC_Asset__c> schemaList = [
            SELECT AEHC_Is_Active__c, AEHC_Environment__c, Approval_Status__c
            FROM AEHC_Asset__c
            WHERE AEHC_Publication__c = :publicationId
            AND RecordType.Name = 'Version'
        ];
        
        Set<String> inProgressStatuses = new Set<String>{
            'Business Owner Subscriber Review',
                'Business Owner Publication Review',
                'Security Architect Review',
                'DDH Admin Review',
                'Submitted to DDH',
                'Pending'
                };
                    
                    Boolean hasActiveDev = false;
        Boolean hasApprovalInProgress = false;
        
        for (AEHC_Asset__c s : schemaList) {
            
            if (s.AEHC_Is_Active__c &&
                s.AEHC_Environment__c != null &&
                s.AEHC_Environment__c.equalsIgnoreCase('Dev')) {
                    hasActiveDev = true;
                }
            
            if (inProgressStatuses.contains(s.Approval_Status__c)) {
                hasApprovalInProgress = true;
            }
            
            if (hasActiveDev && hasApprovalInProgress) {
                break;
            }
        }
        
        return new Map<String, Boolean>{
            'showSubscribe' => hasActiveDev,
                'showPromote'   => !hasApprovalInProgress
                };
                    }
    
    @AuraEnabled(cacheable=true)
    public static ScheduleWrapper getPublisherScheduleDetails(Id recordId) {
        
        Map<String, Object> context = new Map<String, Object>{
            'method' => 'getPublisherScheduleDetails',
                'recordId' => recordId
                };
                    
                    String orgEnv = getCurrentEnvironment();
        
        try {
            
            List<AEHC_Asset__c> assets = [
                SELECT
                AEHC_VSchedule__c,
                AEHC_Frequency__c,
                AEHC_Time__c,
                AEHC_Weekdays__c,
                AEHC_Weeks__c,
                AEHC_Day_of_Month__c,
                AEHC_One_Time_Execution_Date__c,
                AEHC_One_Time_Execution_Time__c,
                AEHC_Schedule_Summary__c,
                AEHC_CRON_Job_Expression__c
                FROM AEHC_Asset__c
                WHERE AEHC_Publication__c = :recordId AND AEHC_Is_Active__c = True
                LIMIT 1
            ];
            
            
            if (assets.isEmpty()) {
                return new ScheduleWrapper();
            }
            
            AEHC_Asset__c asset = assets[0];
            
            
            ScheduleWrapper wrapper = new ScheduleWrapper();
            
            wrapper.schedulerMode = asset.AEHC_VSchedule__c;
            wrapper.frequency = asset.AEHC_Frequency__c;
            wrapper.scheduleSummary = asset.AEHC_Schedule_Summary__c;
            wrapper.cronExpression = asset.AEHC_CRON_Job_Expression__c;
            
            // ✅ Time (convert safely for LWC)
            if (asset.AEHC_Time__c != null) {
                wrapper.scheduleTime = formatTime(asset.AEHC_Time__c);
            }
            
            // ✅ Weekly
            if (!String.isBlank(asset.AEHC_Weekdays__c)) {
                wrapper.weekdays = asset.AEHC_Weekdays__c.split(';');
            }
            
            // ✅ Multi-week
            if (!String.isBlank(asset.AEHC_Weeks__c)) {
                wrapper.multiWeekWeeks = asset.AEHC_Weeks__c.split(';');
            }
            
            if (!String.isBlank(asset.AEHC_Weekdays__c)) {
                wrapper.multiWeekDays = asset.AEHC_Weekdays__c.split(';');
            }
            
            // ✅ Monthly
            wrapper.monthlyDay = asset.AEHC_Day_of_Month__c;
            
            // ✅ One-time
            if (asset.AEHC_One_Time_Execution_Date__c != null) {
                wrapper.oneTimeDate = String.valueOf(asset.AEHC_One_Time_Execution_Date__c);
            }
            
            if (asset.AEHC_One_Time_Execution_Time__c != null) {
                wrapper.oneTimeTime = formatTime(asset.AEHC_One_Time_Execution_Time__c);
            }
            
            return wrapper;
            
        } catch (Exception ex) {
            
            AEHC_Logger.logException(
                ex,
                COMPONENT_TYPE,
                COMPONENT_NAME,
                OPERATION_QUERY,
                recordId,
                SEVERITY_P2,
                CATEGORY,
                context,
                orgEnv
            );
            
            throw new AuraHandledException('Unable to load schedule details.');
        }
    }
    
    private static String formatTime(Time t) {
        if (t == null) return null;
        
        Integer hour = t.hour();
        Integer minute = t.minute();
        
        String hh = hour < 10 ? '0' + hour : String.valueOf(hour);
        String mm = minute < 10 ? '0' + minute : String.valueOf(minute);
        
        return hh + ':' + mm;
    }
    
    private static void setDefaultValues(SubscriptionResponse res) {
        res.applicationId   = 'DEFAULT-APP';
        res.applicationName = 'Default Application';
        res.publicationId   = 'DEFAULT-PUB';
        res.publicationName = 'Default Publication';
        res.environment = 'Dev';
        res.schemaVersion = 'v8';
    }
    
    private static AEHC_Asset__c getActiveSchemaAsset(Id publicationId, String env) {
        
        List<AEHC_Asset__c> assets = [
            SELECT
            Id,
            AEHC_Schema_Version__c,
            AEHC_Schema_Name__c,
            AEHC_Table_Name__c,
            AEHC_Environment__c
            FROM AEHC_Asset__c
            WHERE AEHC_Publication__c = :publicationId
            AND AEHC_Is_Active__c = true
            AND AEHC_Environment__c = :env
            ORDER BY AEHC_Schema_Version__c DESC
            LIMIT 1
        ];
        
        return assets.isEmpty() ? null : assets[0];
    }
    
    private static void populateFromSalesforce(Id recordId, SubscriptionResponse res) {
        
        AEHC_Asset__c obj = getAssetForSubscription(recordId);
        AEHC_Asset__c schemaAsset = getActiveSchemaAsset(obj.Id, 'Dev');
        
        res.applicationRecordId = obj.AEHC_Application__c;
        res.applicationId = obj.AEHC_Application__r.AEHC_Application_Id__c;
        res.applicationName = obj.AEHC_Application__r.Name;
        res.description = obj.AEHC_Description__c;
        
        res.publicationRecordId = obj.Id;
        res.publicationId = obj.AEHC_Publication_Id__c;
        res.publicationName = obj.Name;
        
        res.environment = 'Dev';
        
        if (schemaAsset != null) {
            res.schemaVersion = schemaAsset.AEHC_Schema_Version__c;
            res.schemaName = schemaAsset.AEHC_Schema_Name__c;
            res.tableName = schemaAsset.AEHC_Table_Name__c;
        }
        
        Map<String, Boolean> rules = evaluateButtons(obj.Id);
        
        res.showSubscribe = rules.get('showSubscribe');
        res.showPromote = rules.get('showPromote');
    }
    
    
    private static AEHC_Asset__c getAssetForSubscription(Id recordId,String Env) {
        if (recordId == null) {
            throw new AuraHandledException('Publication record Id is required.');
        }
        List<AEHC_Asset__c> assetList = new  List<AEHC_Asset__c>();
        assetList = [
            SELECT
            Id,
            Name,
            AEHC_Application__c,
            AEHC_Description__c, 
            AEHC_Application__r.Name,
            AEHC_Application__r.AEHC_Application_Id__c,
            AEHC_Publication_Id__c,
            AEHC_Environment__c,
            AEHC_Schema_Version__c,
            AEHC_Schema_Name__c,AEHC_Selected_Fields_JSON__c,
            AEHC_Table_Name__c,AEHC_Publication__r.AEHC_Selected_Fields_JSON__c
            FROM AEHC_Asset__c
            WHERE AEHC_Publication__c = :recordId and AEHC_Environment__c = : env and AEHC_Is_Active__c = true and AEHC_Is_Subscription__c = false order by createddate
            LIMIT 1
        ];
        if(assetList.size() > 0)
        {
            return assetList[0];
        }
        else{
            assetList = new  List<AEHC_Asset__c>();
            assetList = [
                SELECT
                Id,
                Name,
                AEHC_Application__c,
                AEHC_Description__c,
                AEHC_Application__r.Name,
                AEHC_Application__r.AEHC_Application_Id__c,
                AEHC_Publication_Id__c,
                AEHC_Environment__c,
                AEHC_Schema_Version__c,
                AEHC_Schema_Name__c,AEHC_Selected_Fields_JSON__c,
                AEHC_Table_Name__c,AEHC_Publication__r.AEHC_Selected_Fields_JSON__c
                FROM AEHC_Asset__c
                WHERE AEHC_Publication__c = :recordId and AEHC_Environment__c = : env and AEHC_Is_Subscription__c = false order by createddate
                LIMIT 1
            ];
             if(assetList.size() > 0)
            {
                return assetList[0];
            }
        }
        return null;
    }
    
    private static AEHC_Asset__c getAssetForSubscription(Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException('Publication record Id is required.');
        }
        
        return [
            SELECT
            Id,
            Name,
            AEHC_Application__c,
            AEHC_Description__c,
            AEHC_Application__r.Name,
            AEHC_Application__r.AEHC_Application_Id__c,
            AEHC_Publication_Id__c,
            AEHC_Environment__c,
            AEHC_Schema_Version__c,
            AEHC_Schema_Name__c,AEHC_Selected_Fields_JSON__c,
            AEHC_Table_Name__c,AEHC_Publication__r.AEHC_Selected_Fields_JSON__c
            FROM AEHC_Asset__c
            WHERE Id = :recordId
            LIMIT 1
        ];
    }
    
    @AuraEnabled
    public static void submitSubscription() {
        // Prepare context for logging
        Map<String, Object> context = new Map<String, Object>{
            'method' => 'submitSubscription',
                'userId' => UserInfo.getUserId()
                };
                    String orgEnv = getCurrentEnvironment();
        
    }
    
    private static String getCurrentEnvironment() {
        String domain = System.Url.getOrgDomainUrl().getHost().toLowerCase();
        
        if (domain.contains('sandbox') || domain.contains('--') || domain.contains('cs')) {
            // Try to distinguish by naming conventions if present
            if (domain.contains('dev') || domain.contains('--dev')) return 'Dev';
            if (domain.contains('qa')  || domain.contains('--qa'))  return 'QA';
            if (domain.contains('uat') || domain.contains('--uat')) return 'UAT';
            return 'Sandbox'; // Generic sandbox default
        }
        
        return 'Prod';
    }
    
    @AuraEnabled
    public static List<Object> getFieldValues(Id recordId,String env) {
        try{
            AEHC_Asset__c assetVersionDetail = getAssetForSubscription(recordId,env);
            return (List<Object>) JSON.deserializeUntyped(assetVersionDetail.AEHC_Selected_Fields_JSON__c);
        }catch(Exception ex){
            
            System.debug('Field values error : '+ex.getMessage()+ex.getStackTraceString());
            AEHC_Logger.logException(
                ex,
                COMPONENT_TYPE,
                COMPONENT_NAME,
                OPERATION_QUERY,
                recordId,
                SEVERITY_P2,
                CATEGORY,
                null,
                null
            );
            throw new AuraHandledException('Unable to load schema fields.'+ex.getMessage());
        }
        
    }
    @AuraEnabled
    public static List<Object> getTableSchema(Id recordId) {
        
        Map<String, Object> context = new Map<String, Object>{
            'method' => 'getTableSchema',
                'userId' => UserInfo.getUserId(),
                'recordId' => recordId,
                'httpMethod' => 'GET'
                };
                    
                    String orgEnv = getCurrentEnvironment();
        
        try {
            AEHC_Asset__c asset = getAssetForSubscription(recordId);
            AEHC_Asset__c assetVersionDetail = getAssetForSubscription(recordId);
            return (List<Object>) JSON.deserializeUntyped(asset.AEHC_Selected_Fields_JSON__c);
            /*
            Id publicationRecordId = asset.Id;
            String publicationId = asset.AEHC_Publication_Id__c;
            String publicationName = asset.Name;
            String applicationName = asset.AEHC_Application__r.Name;
            
            String environment = DEFAULT_SCHEMA_ENVIRONMENT;
            
            String schemaName = asset.AEHC_Schema_Name__c;
            String tableName  = asset.AEHC_Table_Name__c;
            
            if (String.isBlank(schemaName) || String.isBlank(tableName)) {
                AEHC_Logger.logError(
                    'Schema/Table is missing on Publication record.',
                    COMPONENT_TYPE,
                    COMPONENT_NAME,
                    'getTableSchema',
                    String.valueOf(recordId),
                    SEVERITY_P2,
                    'Validation',
                    context,
                    orgEnv
                );
                throw new AuraHandledException('Schema and Table details are missing for this Publication.');
            }
            
            String dataPublicationName =
                environment + '.' +
                schemaName.trim() + '.' +
                tableName.trim();
            
            context.put('publicationRecordId', String.valueOf(publicationRecordId));
            context.put('publicationName', publicationName);
            context.put('applicationName', applicationName);
            context.put('schemaEnvironment', environment);
            
            context.put('schemaName', schemaName);
            context.put('tableName', tableName);
            context.put('dataPublicationName', dataPublicationName);
            
            
            String endpoint = NAMED_CREDENTIAL_UNITY_CATALOG + dataPublicationName;
            context.put('endpoint', endpoint);
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setTimeout(120000);
            req.setHeader('Accept', 'application/json');
            req.setHeader('Content-Type', 'application/json');
            
            //req.setHeader('client_id', '{!$Credential.UnityCatalogueAPI.client_id}');
            //req.setHeader('client_secret', '{!$Credential.UnityCatalogueAPI.client_secret}');
            
            HttpResponse response = new Http().send(req);
            
            context.put('statusCode', response.getStatusCode());
            context.put('status', response.getStatus());
            if (response.getStatusCode() != 200 || String.isBlank(response.getBody())) {
                AEHC_Logger.logError(
                    'Invalid response from Unity Catalog API. Status=' + response.getStatusCode(),
                    COMPONENT_TYPE,
                    COMPONENT_NAME,
                    'getTableSchema',
                    String.valueOf(recordId),
                    SEVERITY_P2,
                    'Callout',
                    context,
                    orgEnv
                );
                
                throw new AuraHandledException('Unable to load schema fields at this time.');
            }
            
            Map<String, Object> payload =
                (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            
            if (!payload.containsKey('columns') || payload.get('columns') == null) {
                AEHC_Logger.logError(
                    'Schema response does not contain columns.',
                    COMPONENT_TYPE,
                    COMPONENT_NAME,
                    'getTableSchema',
                    String.valueOf(recordId),
                    SEVERITY_P2,
                    'Callout',
                    context,
                    orgEnv
                );
                
                throw new AuraHandledException('Schema response is invalid.');
            }
            
            List<Object> cols = (List<Object>) payload.get('columns');
            List<SchemaColumnDTO> result = new List<SchemaColumnDTO>();
            
            for (Object item : cols) {
                Map<String, Object> columnMap = (Map<String, Object>) item;
                
                SchemaColumnDTO dto = new SchemaColumnDTO();
                
                dto.id = (String) columnMap.get('columnName');
                dto.name = (String) columnMap.get('columnName');
                dto.dataType = (String) columnMap.get('dataType');
                dto.description = (String) columnMap.get('description');
                Object nullableValue = columnMap.get('nullable');
                if (nullableValue == null) {
                    dto.nullable = null;
                } else if (nullableValue instanceof Boolean) {
                    dto.nullable = (Boolean) nullableValue;
                } else {
                    String v = String.valueOf(nullableValue).trim().toLowerCase();
                    dto.nullable = (v == 'true' || v == 'yes' || v == 'y' || v == '1');
                }
                
                Object positionValue = columnMap.get('position');
                
                dto.order = positionValue == null
                    ? null
                    : Integer.valueOf(String.valueOf(positionValue));
                
                result.add(dto);
            }
            
            return result;
            
        } catch (QueryException qe) {
            AEHC_Logger.logException(
                qe,
                COMPONENT_TYPE,
                COMPONENT_NAME,
                OPERATION_QUERY,
                recordId,
                SEVERITY_P2,
                'Query',
                context,
                orgEnv
            );
            
            throw new AuraHandledException('Unable to retrieve publication context for schema fields.');
            
        } catch (CalloutException ce) {
            AEHC_Logger.logException(
                ce,
                COMPONENT_TYPE,
                COMPONENT_NAME,
                OPERATION_QUERY,
                recordId,
                SEVERITY_P2,
                'Callout',
                context,
                orgEnv
            );
            throw new AuraHandledException('Unable to connect to schema service. Please try again later.');
            
        } catch (JSONException je) {
            AEHC_Logger.logException(
                je,
                COMPONENT_TYPE,
                COMPONENT_NAME,
                OPERATION_QUERY,
                recordId,
                SEVERITY_P2,
                'Integration',
                context,
                orgEnv
            );
            
            throw new AuraHandledException('Schema response could not be processed.');
            // */
        } catch (Exception ex) {
            System.debug('Umang'+ex.getMessage()+ex.getStackTraceString());
            AEHC_Logger.logException(
                ex,
                COMPONENT_TYPE,
                COMPONENT_NAME,
                OPERATION_QUERY,
                recordId,
                SEVERITY_P2,
                CATEGORY,
                context,
                orgEnv
            );
            throw new AuraHandledException('Unable to load schema fields.'+ex.getMessage());
        }
    }
    
    private static List<PicklistOptionDTO> getPicklistValuesInternal(
        String objectApiName,
        String fieldApiName
    ) {
        List<PicklistOptionDTO> options = new List<PicklistOptionDTO>();
        
        Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectApiName);
        
        if (objectType == null) {
            return options;
        }
        
        Schema.DescribeSObjectResult objectDescribe = objectType.getDescribe();
        Schema.SObjectField fieldToken = objectDescribe.fields.getMap().get(fieldApiName);
        
        if (fieldToken == null) {
            return options;
        }
        
        Schema.DescribeFieldResult fieldDescribe = fieldToken.getDescribe();
        
        for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
            if (entry.isActive()) {
                PicklistOptionDTO option = new PicklistOptionDTO();
                option.label = entry.getLabel();
                option.value = entry.getValue();
                options.add(option);
            }
        }
        
        return options;
    }
    @AuraEnabled(cacheable=true)
    public static Map<String, List<PicklistOptionDTO>> getAssetPicklistOptions() {
        Map<String, List<PicklistOptionDTO>> result =
            new Map<String, List<PicklistOptionDTO>>();
        
        /*
* Environment field can be backed by Global Value Set.
* Describe API will still return the active values.
*/
        result.put(
            'environmentOptions',
            getPicklistValuesInternal('AEHC_Asset__c', 'AEHC_Environment__c')
        );
        
        return result;
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, List<PicklistOptionDTO>> getSubscriptionPicklistOptions() {
        Map<String, List<PicklistOptionDTO>> result =
            new Map<String, List<PicklistOptionDTO>>();
        
        try {
            // Schedule picklists
            result.put(
                'schedulerModeOptions',
                getPicklistValuesInternal('AEHC_Asset__c', 'AEHC_VSchedule__c')
            );
            
            result.put(
                'frequencyOptions',
                getPicklistValuesInternal('AEHC_Asset__c', 'AEHC_Frequency__c')
            );
            
            result.put(
                'weekdayOptions',
                getPicklistValuesInternal('AEHC_Asset__c', 'AEHC_Weekdays__c')
            );
            
            result.put(
                'weekOptions',
                getPicklistValuesInternal('AEHC_Asset__c', 'AEHC_Weeks__c')
            );
            
            result.put(
                'monthDayOptions',
                getPicklistValuesInternal('AEHC_Asset__c', 'AEHC_Day_of_Month__c')
            );
            
            // Destination picklists
            result.put(
                'destinationTypeOptions',
                getPicklistValuesInternal('AEHC_Asset__c', 'AEHC_Destination_Type__c')
            );
            
            result.put(
                'databaseTypeOptions',
                getPicklistValuesInternal('AEHC_Asset__c', 'AEHC_Database_Type__c')
            );
            
            result.put(
                'outputFormatOptions',
                getPicklistValuesInternal('AEHC_Asset__c', 'AEHC_Output_Format__c')
            );
            
            // Environment picklist, backed by global value set if field uses one
            result.put(
                'environmentOptions',
                getPicklistValuesInternal('AEHC_Asset__c', 'AEHC_Environment__c')
            );
            
            return result;
            
        } catch (Exception ex) {
            Map<String, Object> context = new Map<String, Object>{
                'method' => 'getSubscriptionPicklistOptions',
                    'userId' => UserInfo.getUserId()
                    };
                        
                        AEHC_Logger.logException(
                            ex,
                            'Apex',
                            'AEHC_SubscriptionController_DP',
                            'getSubscriptionPicklistOptions',
                            null,
                            'P2',
                            'Metadata',
                            context,
                            getCurrentEnvironment()
                        );
            
            throw new AuraHandledException('Unable to load picklist options.');
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static SubscriptionEditContextResponse getSubscriptionEditContext(Id subscriptionId) {
        
        if (subscriptionId == null) {
            throw new AuraHandledException('Subscription Id is required');
        }
        
        Id currentUserId = UserInfo.getUserId();
        
        /*
✅ STEP 1: Fetch Subscription
*/
        Subscription__c sub = [
            SELECT Id,
            AEHC_Application_Name__r.Name,
            AEHC_Publication_ID__r.Name,
            AEHC_Publication_ID__c,
            AEHC_Purpose_of_Use__c,
            Subscriber__c,
            AEHC_Consumming_Application__c
            FROM Subscription__c
            WHERE Id = :subscriptionId
            AND RecordType.Name = 'Data Publication'
            LIMIT 1
        ];
        
        /*
✅ STEP 2: Authorization Check
*/
        Boolean isSubscriber = sub.Subscriber__c == currentUserId;
        Boolean isBusinessOwner = false;
        
        if (!isSubscriber && sub.AEHC_Consumming_Application__c != null) {
            List<AEHC_AssetMember__c> members = [
                SELECT Id
                FROM AEHC_AssetMember__c
                WHERE AEHC_Asset__c = :sub.AEHC_Consumming_Application__c
                AND AEHC_Role__c = 'Business Owner'
                AND AEHC_User__c = :currentUserId
                LIMIT 1
            ];
            
            isBusinessOwner = !members.isEmpty();
        }
        
        if (!isSubscriber && !isBusinessOwner) {
            throw new AuraHandledException('You are not authorized to edit this subscription');
        }
        
        /*
✅ STEP 3: Fetch all versions
*/
        List<AEHC_Asset__c> versions = [
            SELECT Id,
            AEHC_Environment__c,
            AEHC_Schema_Version__c,
            Approval_Status__c
            FROM AEHC_Asset__c
            WHERE RecordType.Name = 'AEHC_Version'
            AND AEHC_Is_Subscription__c = true
            AND AEHC_Subscription_Request__c = :subscriptionId
            ORDER BY AEHC_Environment__c, AEHC_Schema_Version__c DESC
        ];
        
        /*
✅ STEP 4: Build environment list
*/
        Map<String, List<AEHC_Asset__c>> envMap = new Map<String, List<AEHC_Asset__c>>();
        
        for (AEHC_Asset__c v : versions) {
            String env = v.AEHC_Environment__c;
            if (String.isBlank(env)) continue;
            
            if (!envMap.containsKey(env)) {
                envMap.put(env, new List<AEHC_Asset__c>());
            }
            envMap.get(env).add(v);
        }
        
        /*
✅ STEP 5: Determine default environment
Priority:
Draft → Dev → Any
*/
        String defaultEnv;
        Boolean draftFound = false;
        
        for (String env : envMap.keySet()) {
            for (AEHC_Asset__c v : envMap.get(env)) {
                if (v.Approval_Status__c == 'Draft' && !draftFound) {
                    defaultEnv = env;
                    draftFound = true;
                    break;
                }
            }
            if (draftFound) break;
        }
        
        if (String.isBlank(defaultEnv)) {
            if (envMap.containsKey('Dev')) {
                defaultEnv = 'Dev';
            } else if (!envMap.isEmpty()) {
                defaultEnv = envMap.keySet().iterator().next();
            }
        }
        
        /*
✅ STEP 6: Prepare Response
*/
        SubscriptionEditContextResponse res = new SubscriptionEditContextResponse();
        res.applicationName = sub.AEHC_Application_Name__r.Name;
        res.publicationName = sub.AEHC_Publication_ID__r.Name;
        res.publicationRecordId = sub.AEHC_Publication_ID__c;
        res.availableEnvironments = new List<String>(envMap.keySet());
        res.defaultEnvironment = defaultEnv;
        
        return res;
    }
    
    @AuraEnabled(cacheable=true)
    public static SubscriptionVersionResponse getSubscriptionVersionByEnv(
        Id subscriptionId,
        String environment,
        String versionNumber
    ) {
        if (subscriptionId == null || String.isBlank(environment) || String.isBlank(versionNumber)) {
            throw new AuraHandledException('Invalid input');
        }
        
        List<AEHC_Asset__c> versions = [
            SELECT Id,
            Name,
            AEHC_Environment__c,
            AEHC_Schema_Version__c,
            Approval_Status__c,
            AEHC_Is_Active__c,
            AEHC_Subscription_Request__r.AEHC_Consumming_Application__c,
            AEHC_Subscription_Request__r.AEHC_Consumming_Application__r.Name,
            AEHC_Subscription_Request__r.AEHC_UAT_Approval__c,
            /* ✅ BASIC INFO */
            AEHC_Purpose_of_Use__c,
            AEHC_Transformation_Required__c,
            AEHC_Description__c,
            
            AEHC_Application__c,
            AEHC_Application__r.Name,
            AEHC_Application__r.AEHC_Application_Id__c,
            AEHC_Publication__c,
            AEHC_Publication__r.Name,
            AEHC_Publication__r.AEHC_Publication_Id__c,
            AEHC_Subscription_Request__r.AEHC_Latest_Version__c,
            AEHC_Subscription_Request__r.AEHC_Purpose_of_Use__c,
            /* ✅ SELECTED FIELDS */
            AEHC_Selected_Fields_JSON__c,
            
            /* ✅ SCHEDULE */
            AEHC_VSchedule__c,
            AEHC_Frequency__c,
            AEHC_Time__c,
            AEHC_Weekdays__c,
            AEHC_Weeks__c,
            AEHC_Day_of_Month__c,
            AEHC_One_Time_Execution_Date__c,
            AEHC_One_Time_Execution_Time__c,
            AEHC_Schedule_Summary__c,
            AEHC_CRON_Job_Expression__c,
            
            /* ✅ DESTINATION */
            AEHC_Destination_Type__c,
            AEHC_Storage_Account_Bucket__c,
            AEHC_Container_Folder_Path__c,
            AEHC_Output_Format__c,
            AEHC_Blob_FileName__c,
            
            AEHC_Database_Type__c,
            AEHC_Host_Server__c,
            AEHC_Port__c,
            AEHC_JDBC_URL__c,
            AEHC_Other_Properties__c,
            AEHC_Batch_Flag__c,
            AEHC_BatchSize__c,
            AEHC_On_Initialization__c,
            AEHC_On_Load__c,
            AEHC_On_Success__c,
            AEHC_On_Error__c,
            AEHC_Mute_Error_Flag__c,
            
            AEHC_Remote_Directory_Path__c,
            AEHC_Filename__c,
            AEHC_Include_Header__c,
            AEHC_Provide_Custom_Header__c,
            AEHC_Delimiter__c
            
            FROM AEHC_Asset__c
            WHERE AEHC_Subscription_Request__c = :subscriptionId
            AND AEHC_Environment__c = :environment
            AND AEHC_Schema_Version__c = :versionNumber
            LIMIT 1
        ];
        
        if (versions.isEmpty()) {
            throw new AuraHandledException('Version not found');
        }
        
        AEHC_Asset__c v = versions[0];
        
        SubscriptionVersionResponse res = new SubscriptionVersionResponse();
        
        /*
✅ BASIC INFO
*/
        res.environment = v.AEHC_Environment__c;
        res.versionNumber = v.AEHC_Schema_Version__c;
        res.nextversionNumber = String.valueOf((v.AEHC_Subscription_Request__r.AEHC_Latest_Version__c == NULL ? 1 :v.AEHC_Subscription_Request__r.AEHC_Latest_Version__c) +1);
        res.isDraft = (v.Approval_Status__c == '' || v.Approval_Status__c == 'Rejected');
        res.approvalStatus = v.Approval_Status__c;
        res.versionRecordId = v.Id;
        res.purposeOfUse = v.AEHC_Subscription_Request__r.AEHC_Purpose_of_Use__c;
        res.transformationRequired = v.AEHC_Transformation_Required__c;
        res.versionisActive = v.AEHC_Is_Active__c;
        res.uatEnabled = v.AEHC_Subscription_Request__r.AEHC_UAT_Approval__c;
        res.applicationName = v.AEHC_Application__r != null ? v.AEHC_Application__r.Name : null;
        //res.applicationId = v.AEHC_Application__r.AEHC_Application_Id__c;
        res.applicationRecordId = v.AEHC_Application__c;
        res.consumingApplication = v.AEHC_Subscription_Request__r.AEHC_Consumming_Application__c != null ? v.AEHC_Subscription_Request__r.AEHC_Consumming_Application__c : null;
        res.consumingApplicationName = v.AEHC_Subscription_Request__r.AEHC_Consumming_Application__c != null ? v.AEHC_Subscription_Request__r.AEHC_Consumming_Application__r.Name : null;
        res.publicationName = v.AEHC_Publication__r != null ? v.AEHC_Publication__r.Name : null;
        res.publicationId = v.AEHC_Publication__r.AEHC_Publication_Id__c;
        res.publicationRecordId = v.AEHC_Publication__c;
        
        res.description = v.AEHC_Description__c;
        
        /*
✅ SELECTED FIELDS
*/
        if (!String.isBlank(v.AEHC_Selected_Fields_JSON__c)) {
            res.selectedFieldsJson =
                (List<Object>) JSON.deserializeUntyped(v.AEHC_Selected_Fields_JSON__c);
        } else {
            res.selectedFieldsJson = new List<Object>();
        }
        
        /*
✅ SCHEDULE
*/
        ScheduleWrapper sch = new ScheduleWrapper();
        
        sch.schedulerMode = v.AEHC_VSchedule__c;
        sch.frequency = v.AEHC_Frequency__c;
        sch.scheduleSummary = v.AEHC_Schedule_Summary__c;
        sch.cronExpression = v.AEHC_CRON_Job_Expression__c;
        
        if (v.AEHC_Time__c != null) {
            sch.scheduleTime = String.valueOf(v.AEHC_Time__c);
        }
        
        if (!String.isBlank(v.AEHC_Weekdays__c)) {
            sch.weekdays = v.AEHC_Weekdays__c.split(';');
        }
        
        if (!String.isBlank(v.AEHC_Weeks__c)) {
            sch.multiWeekWeeks = v.AEHC_Weeks__c.split(';');
        }
        
        sch.monthlyDay = v.AEHC_Day_of_Month__c;
        
        if (v.AEHC_One_Time_Execution_Date__c != null) {
            sch.oneTimeDate = String.valueOf(v.AEHC_One_Time_Execution_Date__c);
        }
        
        if (v.AEHC_One_Time_Execution_Time__c != null) {
            sch.oneTimeTime = String.valueOf(v.AEHC_One_Time_Execution_Time__c);
        }
        
        res.schedule = sch;
        
        /*
✅ DESTINATION
*/
        Map<String, Object> dest = new Map<String, Object>();
        dest.put('destinationType', v.AEHC_Destination_Type__c);
        
        if (v.AEHC_Destination_Type__c == 'BLOB') {
            dest.put('storageAccount', v.AEHC_Storage_Account_Bucket__c);
            dest.put('containerPath', v.AEHC_Container_Folder_Path__c);
            dest.put('outputFormat', v.AEHC_Output_Format__c);
            dest.put('blobFileName', v.AEHC_Blob_FileName__c);
            dest.put('includeHeader', v.AEHC_Include_Header__c);
            dest.put('provideCustomHeader', v.AEHC_Provide_Custom_Header__c);
            dest.put('delimiter', v.AEHC_Delimiter__c);
        }
        
        if (v.AEHC_Destination_Type__c == 'Database') {
            dest.put('databaseType', v.AEHC_Database_Type__c);
            dest.put('databaseHost', v.AEHC_Host_Server__c);
            dest.put('databasePort', v.AEHC_Port__c);
            dest.put('jdbcUrl', v.AEHC_JDBC_URL__c);
            dest.put('otherProperties', v.AEHC_Other_Properties__c);
            dest.put('batchFlag', v.AEHC_Batch_Flag__c);
            dest.put('batchSize', v.AEHC_BatchSize__c);
            dest.put('spOnInit', v.AEHC_On_Initialization__c);
            dest.put('spOnLoad', v.AEHC_On_Load__c);
            dest.put('spOnSuccess', v.AEHC_On_Success__c);
            dest.put('spOnError', v.AEHC_On_Error__c);
            dest.put('muteErrorFlag', v.AEHC_Mute_Error_Flag__c);
            dest.put('provideCustomHeader', v.AEHC_Provide_Custom_Header__c);
        }
        
        if (v.AEHC_Destination_Type__c == 'SFTP') {
            dest.put('sftpHostName', v.AEHC_Host_Server__c);
            dest.put('sftpPort', v.AEHC_Port__c);
            dest.put('sftpRemotePath', v.AEHC_Remote_Directory_Path__c);
            dest.put('sftpFileName', v.AEHC_Filename__c);
            dest.put('sftpOutputFormat', v.AEHC_Output_Format__c);
            dest.put('includeHeader', v.AEHC_Include_Header__c);
            dest.put('provideCustomHeader', v.AEHC_Provide_Custom_Header__c);
            dest.put('delimiter', v.AEHC_Delimiter__c);
        }
        
        res.destination = dest;
        
        return res;
    }
    
    @AuraEnabled(cacheable=true)
    public static Boolean isUserPublicationBO(Id publicationId) {
        
        if (publicationId == null) return false;
        
        Id currentUserId = UserInfo.getUserId();
        
        //  Get Application from Publication
        AEHC_Asset__c pub = [
            SELECT AEHC_Application__c
            FROM AEHC_Asset__c
            WHERE Id = :publicationId
            LIMIT 1
        ];
        
        if (pub.AEHC_Application__c == null) return false;
        
        //  Check Asset Member
        Integer countRec = [
            SELECT COUNT()
            FROM AEHC_AssetMember__c
            WHERE AEHC_Asset__c = :pub.AEHC_Application__c
            AND AEHC_User__c = :currentUserId
            AND AEHC_Role__c = 'Business Owner'
        ];
        
        return countRec > 0;
    }
    @AuraEnabled(cacheable=true)
    public static Boolean checkEligibilityBasedOnRole(Id publicationId) {
        
        if (publicationId == null) {
            return false;
        }
        
        Id currentUserId = UserInfo.getUserId();
        
        try {
            
            // ✅ Step 1: Get Application via Subscription → Publication
            AEHC_Asset__c asset = [
                SELECT AEHC_Application__c
                FROM AEHC_Asset__c
                WHERE Id = :publicationId
                LIMIT 1
            ];
            
            if (asset.AEHC_Application__c == null) {
                return false;
            }
            
            Id applicationId = asset.AEHC_Application__c;
            
            // ✅ Step 2: Check if user has required role
            Integer countRecords = [
                SELECT COUNT()
                FROM AEHC_AssetMember__c
                WHERE AEHC_Asset__c = :applicationId
                AND AEHC_User__c = :currentUserId
                AND AEHC_Role__c IN ('Developer', 'Business Owner')
            ];
            
            // ✅ Step 3: Return TRUE/FALSE
            return countRecords > 0;
            
        } catch (Exception e) {
            
            AEHC_Logger.logException(
                e,
                'Apex',
                'AEHC_PublicationSubRequestController.isUserDeveloperOrBusinessOwner',
                'role-check',
                publicationId,
                'P2',
                'Security',
                null,
                AEHC_Utility.getCurrentEnvironment()
            );
            
            return false;
        }
    }

    @AuraEnabled(cacheable=true)
    public static Boolean canEditPublication(Id publicationId) {

        // Existing role validation
        Boolean hasRole = checkEligibilityBasedOnRole(publicationId);

        if (!hasRole) {
            return false;
        }

        // Get latest version
        AEHC_Asset__c latestActiveVersion = [ SELECT Id, Name, Approval_Status__c,AEHC_Is_Active__c FROM AEHC_Asset__c WHERE AEHC_Publication__c = :publicationId
                      ORDER BY AEHC_Schema_Version__c DESC LIMIT 1 ];

        return latestActiveVersion != null && latestActiveVersion.AEHC_Is_Active__c == true;
    }
    
}