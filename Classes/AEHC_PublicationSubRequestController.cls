public with sharing class AEHC_PublicationSubRequestController {
    
    private static final String COMPONENT_TYPE = 'Apex';
    private static final String COMPONENT_NAME = 'AEHC_PublicationSubRequestController';
    private static final String SEVERITY_P2 = 'P2';
    private static final String CATEGORY_DML = 'DML';
    private static final String CATEGORY_SUBSCRIPTION = 'Subscription';
    private static final String SAFE_SUBMIT_ERROR = 'Unable to submit subscription. Please try again later.';
    private static final String DEV_ENV = 'Dev';
    
    // Wrapper matching LWC structure
    public class SubscriptionRequestWrapper {
        public String applicationId;
        public String applicationName;
        public String subscriberApplication;
        public String publicationName;
        public String publicationId;
        public String environment;
        public String schemaVersion;
        public String purposeOfUse;
        public Boolean transformationRequired;
        public List<SelectedFieldWrapper> selectedFields;
        public List<SelectedFieldJsonWrapper> selectedFieldsJson;
        public ScheduleWrapper schedule;
        public DestinationWrapper destination;
        public Boolean editMode;
        public String editAction;
        public Id versionRecordId;
        public Boolean uatEnabled;
    }
    
    public class SelectedFieldWrapper {
        public String name;
        public String dataType;
        public String description;
        public Boolean nullable;
        public Integer order;
    }
    
    public class SaveSubscriptionResponse {
        @AuraEnabled public Id subscriptionId;
        @AuraEnabled public String requestNumber;
        @AuraEnabled public String environment;
        @AuraEnabled public String schemaVersion;
        @AuraEnabled public String actionType;
    }
    
    public class SelectedFieldJsonWrapper {
        public String fieldName;
        public String label;
        public Integer order;
    }
    
    public class ScheduleWrapper {
        public String schedulerMode;
        public String frequency;
        public String scheduleTime;
        public String oneTimeDate;
        public String oneTimeTime;
        public List<String> weekdays;
        public List<String> multiWeekWeeks;
        public List<String> multiWeekDays;
        public String monthlyDay;
        public String scheduleSummary;
        public String cronExpression;
    }
    
    public class DestinationWrapper {
        public String destinationType;
        
        // Blob
        public String storageAccount;
        public String containerPath;
        public String outputFormat;
        public String blobFileName;
        
        // Database
        public String databaseType;
        public String databaseHost;
        public String databasePort;
        public String jdbcUrl;
        public String otherProperties;
        public Boolean batchFlag;
        public String batchSize;
        public String spOnInit;
        public String spOnLoad;
        public String spOnSuccess;
        public String spOnError;
        public Boolean muteErrorFlag;
        
        // SFTP
        public String sftpHostName;
        public String sftpPort;
        public String sftpRemotePath;
        public String sftpFileName;
        public String sftpOutputFormat;
        public Boolean includeHeader;
        public Boolean provideCustomHeader;
        public String delimiter;
    }
    
    @AuraEnabled
    public static SaveSubscriptionResponse saveSubscription(String requestJson, Id publicationRecordId, Id applicationRecordId) {
        
        if (publicationRecordId == null) {
            throw new AuraHandledException('Publication record Id is required.');
        }
        if (String.isBlank(requestJson)) {
            throw new AuraHandledException('Request payload cannot be empty.');
        }
        AEHC_Asset__c pubVersion;
        
        AEHC_Asset__c publication = [ SELECT Id, Name, AEHC_Publication_Id__c, AEHC_Application__r.AEHC_Application_Id__c, AEHC_Application__r.Name,AEHC_Application__c, AEHC_Publication_Type__c FROM AEHC_Asset__c
                                     WHERE Id = :publicationRecordId LIMIT 1];
        /*if(publication!= null){
             pubVersion = [ SELECT Id, AEHC_Schema_Version__c FROM AEHC_Asset__c WHERE AEHC_Publication__c = :publicationRecordId AND AEHC_Environment__c = 'Dev' AND AEHC_Is_Active__c = true LIMIT 1];
        }*/
        Savepoint sp = Database.setSavepoint();
        
        try {
            SubscriptionRequestWrapper req = (SubscriptionRequestWrapper) JSON.deserialize(requestJson, SubscriptionRequestWrapper.class);
            if (req == null) {
                throw new AuraHandledException('Invalid request format.');
            }
            Boolean uatValue = req.uatEnabled != null ? req.uatEnabled : false;
            if (req.editMode == true) {
                AEHC_Asset__c existingVer = [ SELECT Id, AEHC_Is_Active__c, AEHC_Subscription_Request__c,AEHC_Subscription_Request__r.name, AEHC_Schema_Version__c FROM AEHC_Asset__c WHERE Id = :req.versionRecordId LIMIT 1];
                Id existingSubscriptionId = existingVer.AEHC_Subscription_Request__c;
                
                if (req.editAction == 'UPDATE') {
                    
                    /* UPDATE EXISTING VERSION */
                    AEHC_Asset__c existing = [
                        SELECT Id,Name, AEHC_Is_Active__c, AEHC_Subscription_Request__c,AEHC_Subscription_Request__r.Name, 
                        		Approval_Status__c,AEHC_Environment__c,AEHC_Schema_Version__c
                        FROM AEHC_Asset__c
                        WHERE Id = :req.versionRecordId
                        LIMIT 1
                    ];
                    
                    existing.AEHC_Purpose_of_Use__c = req.purposeOfUse;
                    existing.AEHC_Transformation_Required__c = req.transformationRequired;
                    existing.AEHC_UAT_Approval__c = uatValue;
                    existing.AEHC_Selected_Fields_JSON__c = req.selectedFieldsJson != null
                        ? JSON.serialize(req.selectedFieldsJson)
                        : null;
                    
                    applyScheduleToAsset(existing, req.schedule);
                    applyDestinationToAsset(existing, req.destination);
                    Boolean needsResubmit = false;
                    if (existing.Approval_Status__c == 'Rejected') {

                        needsResubmit = true;
                        String approvalStatus = 'DDH Admin Review'; // default

                        try {

                            List<ProcessInstanceStep> rejectedSteps = [SELECT OriginalActorId, OriginalActor.Name FROM ProcessInstanceStep 
                            WHERE ProcessInstance.TargetObjectId = :existing.Id AND StepStatus = 'Rejected' ORDER BY CreatedDate DESC LIMIT 1];

                            if (!rejectedSteps.isEmpty()) {
                                System.debug('Rejected record => ' + rejectedSteps);
                                String queueName = rejectedSteps[0].OriginalActor != null ? rejectedSteps[0].OriginalActor.Name : '';
                                System.debug('Rejected Queue Name => ' + queueName);

                                if (!String.isBlank(queueName)) {  
                                    if (queueName.equalsIgnoreCase('Subscriber Business Owner')) {
                                        approvalStatus = 'Business Owner Subscriber Review';
                                    } else if (queueName.equalsIgnoreCase('Publication Business Owner')) {
                                        approvalStatus = 'Business Owner Publication Review';
                                    } else if (queueName.equalsIgnoreCase('AEHC DDH Admin')) {
                                        approvalStatus = 'DDH Admin Review';
                                    } else if (queueName.equalsIgnoreCase('AEHC ADL Approver')) {
                                        approvalStatus = 'Pending ADL Review';
                                    } else if (queueName.equalsIgnoreCase('Security Architect')) {
                                        approvalStatus = 'Security Architect Review';
                                    }
                                }
                            }

                        } catch (Exception ex) {
                            System.debug('Unable to determine previous approval queue. Defaulting to DDH Admin Review');
                        }
                        existing.Approval_Status__c = approvalStatus;
                    }
                    
                    Database.SaveResult sr = Database.update(existing, false);

                    Subscription__c subscriptionReq = new Subscription__c(Id = existingSubscriptionId, AEHC_Purpose_of_Use__c = req.purposeOfUse);
                    update subscriptionReq;

                    
                    if (!sr.isSuccess()) {
                        logSaveErrors(sr, 'UPDATE_EXISTING_VERSION', req.versionRecordId, requestJson);
                        System.debug('data'+sr);
                        throw new AuraHandledException(SAFE_SUBMIT_ERROR);
                    }
                    if (needsResubmit) {
                        try {

                            Approval.ProcessSubmitRequest submitReq = new Approval.ProcessSubmitRequest();

                            submitReq.setObjectId(existing.Id);
                            submitReq.setComments('Automatically resubmitted after rejected subscription was updated');

                            Approval.ProcessResult result = Approval.process(submitReq);
                            System.debug('Approval Resubmit Success: ' + result.isSuccess());
                            if (result.isSuccess()) {

                                Subscription__c subscriptionRec = [SELECT Id, Subscriber__c FROM Subscription__c WHERE Id = :existingSubscriptionId LIMIT 1];

                                if (subscriptionRec.Subscriber__c != null) {
                                    sendResubmittedNotification(subscriptionRec.Subscriber__c, existingSubscriptionId, existing.Name,existing.AEHC_Environment__c,
                                                                existing.AEHC_Schema_Version__c);
                                }
                            }

                        } catch (Exception approvalEx) {
                            throw new AuraHandledException('Record updated successfully but failed to resubmit for approval. ' + approvalEx.getMessage());
                        }
                    }
                    
                    SaveSubscriptionResponse response = new SaveSubscriptionResponse();
                     response.subscriptionId = existingSubscriptionId;
                    response.requestNumber = existingVer.AEHC_Subscription_Request__r.Name;
                    response.environment = req.environment;
                    response.schemaVersion = req.schemaVersion;
                    response.actionType = 'UPDATE';
                    
                    return response;
                    
                }
                
                if (req.editAction == 'CREATE_NEW_VERSION') {

                    AEHC_Asset__c newVersion = new AEHC_Asset__c();
                    
                    newVersion.Name = buildVersionName(
                        req.applicationName,
                        req.publicationName,
                        DEV_ENV,
                        req.schemaVersion
                    );
                    
                    // reuse publication safely
                    newVersion.AEHC_Publication__c = publicationRecordId;
                    newVersion.AEHC_Application__c = applicationRecordId;
                    newVersion.AEHC_Subscription_Request__c = existingSubscriptionId;
                    newVersion.AEHC_Publication_Id__c = publication.AEHC_Publication_Id__c;
                    newVersion.AEHC_Application_Id__c = publication.AEHC_Application__r.AEHC_Application_Id__c;
                    newVersion.AEHC_Previous_Version__c = req.versionRecordId;
                    newVersion.AEHC_UAT_Approval__c = uatValue;
                    newVersion.AEHC_IntId__c=getIntId(publication.AEHC_Application__c, publication.Id, DEV_ENV,'1', true,existingSubscriptionId);

                    newVersion.RecordTypeId = getRecordTypeIdByDeveloperName(
                        AEHC_Asset__c.SObjectType,
                        'AEHC_Version'
                    );
                    
                    newVersion.AEHC_Environment__c = DEV_ENV;
                    newVersion.Approval_Status__c = 'Business Owner Subscriber Review';
                    newVersion.AEHC_Schema_Version__c = req.schemaVersion;
                    
                    newVersion.AEHC_Is_Subscription__c = true;
                    
                    newVersion.AEHC_Purpose_of_Use__c = req.purposeOfUse;
                    newVersion.AEHC_Transformation_Required__c = req.transformationRequired;
                    
                    newVersion.AEHC_Selected_Fields_JSON__c = req.selectedFieldsJson != null
                        ? JSON.serialize(req.selectedFieldsJson)
                        : null;
                    
                    applyScheduleToAsset(newVersion, req.schedule);
                    applyDestinationToAsset(newVersion, req.destination);
                    
                    
                    Database.SaveResult sr = Database.insert(newVersion, false);
                    Subscription__c subscriptionReq = new Subscription__c(Id = existingSubscriptionId, AEHC_Purpose_of_Use__c = req.purposeOfUse);
                    update subscriptionReq;
                    if (!sr.isSuccess()) {
                        logSaveErrors(sr, 'INSERT_NEW_VERSION', newVersion.Id,requestJson );
                        throw new AuraHandledException(SAFE_SUBMIT_ERROR);
                    }
                    
                    Subscription__c updateSubs = [Select id,AEHC_Latest_Version__c  from Subscription__c  where Id = :existingSubscriptionId];
                    updateSubs.AEHC_Latest_Version__c = Integer.valueOf(req.schemaVersion);
                    update updateSubs;
                    
                    SaveSubscriptionResponse response = new SaveSubscriptionResponse();
                    response.subscriptionId = existingSubscriptionId;
                    response.requestNumber = existingVer.AEHC_Subscription_Request__r.Name;
                    response.environment = DEV_ENV;
                    response.schemaVersion = req.schemaVersion;
                    response.actionType = 'NEW_VERSION';
                    
                    return response;
                    
                }
            }
            
            
            String appName = publication.AEHC_Application__r.Name;
            String pubName = publication.Name;
            
            String finalName = buildVersionName(
                appName,
                pubName,
                req.environment,
                req.schemaVersion
            );
            
            /*
* Subscription__c stores the request / approval shell only.
* Application Name / Application lookup / Environment / Schema Version
* are intentionally not stored on Subscription__c.
* They can be surfaced by formula fields, and Environment / Schema Version
* are stored on the schema Asset record below.
*/
            Subscription__c subscriptionRequest = new Subscription__c();
            subscriptionRequest.AEHC_Publication_ID__c = publicationRecordId;
            subscriptionRequest.AEHC_Application_Name__c = applicationRecordId;
            subscriptionRequest.AEHC_Purpose_of_Use__c = req.purposeOfUse;
            subscriptionRequest.AEHC_Consumming_Application__c = req.subscriberApplication;
            subscriptionRequest.AEHC_Transformation_Required__c = req.transformationRequired;
            subscriptionRequest.Subscriber__c = UserInfo.getUserId();
            subscriptionRequest.AEHC_AssetType__c = publication.AEHC_Publication_Type__c;
            subscriptionRequest.AEHC_Environment__c = DEV_ENV;
            subscriptionRequest.AEHC_Environment_Name__c = DEV_ENV;
            subscriptionRequest.AEHC_Latest_Version__c = 1;
            subscriptionRequest.AEHC_UAT_Approval__c = uatValue;
            subscriptionRequest.RecordTypeId = getRecordTypeIdByDeveloperName(
                Subscription__c.SObjectType,
                System.Label.AEHC_SubReq_DataPublication_RecType
            );
            
            Database.SaveResult subscriptionResult = Database.insert(subscriptionRequest, false);
            
            if (!subscriptionResult.isSuccess()) {
                Database.rollback(sp);
                logSaveErrors(subscriptionResult, 'insertSubscriptionRequest', publicationRecordId, requestJson);
                throw new AuraHandledException(SAFE_SUBMIT_ERROR+subscriptionResult);
            }
            
            Id subscriptionRequestId = subscriptionResult.getId();
            
            /*
            * AEHC_Asset__c schema record stores selected fields, schedule,
            * destination metadata, Environment, and Schema Version.
            */
            AEHC_Asset__c schemaAsset = new AEHC_Asset__c();
            schemaAsset.Name = String.isNotBlank(finalName) ? finalName : 'Subscription Schema';
            schemaAsset.RecordTypeId = getRecordTypeIdByDeveloperName(
                AEHC_Asset__c.SObjectType,
                'AEHC_Version'
            );
            schemaAsset.AEHC_Subscription_Request__c = subscriptionRequestId;
            schemaAsset.AEHC_Publication__c = publicationRecordId;
            schemaAsset.AEHC_SubscriberApplication__c = req.subscriberApplication;
            schemaAsset.AEHC_Publication_Id__c = publication.AEHC_Publication_Id__c;
            schemaAsset.AEHC_Application_Id__c = publication.AEHC_Application__r.AEHC_Application_Id__c;
            schemaAsset.AEHC_Is_Subscription__c = true;
            schemaAsset.AEHC_Application__c = applicationRecordId;
            schemaAsset.AEHC_Environment__c = req.environment;
            schemaAsset.AEHC_Schema_Version__c = String.isNotBlank(req.schemaVersion) ? req.schemaVersion : '1';
            schemaAsset.AEHC_Purpose_of_Use__c = req.purposeOfUse;
            schemaAsset.AEHC_Transformation_Required__c = req.transformationRequired;
            schemaAsset.Approval_Status__c = 'Business Owner Subscriber Review';
            schemaAsset.AEHC_Selected_Fields_JSON__c = req.selectedFieldsJson != null ? JSON.serialize(req.selectedFieldsJson) : null;
            
            applyScheduleToAsset(schemaAsset, req.schedule);
            applyDestinationToAsset(schemaAsset, req.destination);
            
            Database.SaveResult schemaAssetResult = Database.insert(schemaAsset, false);
            
            if (!schemaAssetResult.isSuccess()) {
                Database.rollback(sp);
                logSaveErrors(schemaAssetResult, 'insertSchemaAsset', subscriptionRequestId, requestJson);
                throw new AuraHandledException(SAFE_SUBMIT_ERROR);
            }
            
            Subscription__c savedSubscription = [SELECT Id, Name FROM Subscription__c WHERE Id = :subscriptionRequestId LIMIT 1];
            
            SaveSubscriptionResponse response = new SaveSubscriptionResponse();
            response.subscriptionId = savedSubscription.Id;
            response.requestNumber = savedSubscription.Name;
            response.environment = req.environment;
            response.schemaVersion = schemaAsset.AEHC_Schema_Version__c;
            response.actionType = 'CREATE';
            
            return response;
            
        } catch (AuraHandledException ahe) {
            throw ahe;
            
        } catch (JSONException jsonEx) {
            Database.rollback(sp);
            logException(
                jsonEx,
                'saveSubscription_JSON',
                publicationRecordId,
                requestJson
            );
            throw new AuraHandledException(SAFE_SUBMIT_ERROR);
            
        } catch (Exception ex) {
            Database.rollback(sp);
            logException(
                ex,
                'saveSubscription',
                publicationRecordId,
                requestJson
            );
            //throw new AuraHandledException(SAFE_SUBMIT_ERROR);
            return null;
        }
    }
    public static String buildVersionName(
    String appName,
    String pubName,
    String env,
    String schemaVersion
    ) {
        String version = String.isNotBlank(schemaVersion)
            ? schemaVersion
            : '1';

    // Normalize version
        String normalized = version.toUpperCase().startsWith('V')
            ? version
            : 'V' + version;

        String suffix = '_' + env + '_' + normalized;

        String baseName = appName + '_' + pubName;

        Integer maxLength = 80;

        if ((baseName + suffix).length() > maxLength) {
            Integer allowedLength = maxLength - suffix.length();

            if (allowedLength > 0) {
                baseName = baseName.substring(
                    0,
                    Math.min(baseName.length(), allowedLength)
                );
            }
        }

        return baseName + suffix;
    }
    
    private static void applyScheduleToAsset(AEHC_Asset__c schemaAsset, ScheduleWrapper schedule) {
        if (schedule == null) {
            return;
        }
        
        schemaAsset.AEHC_Time__c = null;
        schemaAsset.AEHC_Weekdays__c = null;
        schemaAsset.AEHC_Weeks__c = null;
        schemaAsset.AEHC_Day_of_Month__c = null;
        schemaAsset.AEHC_One_Time_Execution_Time__c = null;
        schemaAsset.AEHC_One_Time_Execution_Date__c = null;
        
        schemaAsset.AEHC_VSchedule__c = schedule.schedulerMode;
        schemaAsset.AEHC_Frequency__c = schedule.frequency;
        schemaAsset.AEHC_Schedule_Summary__c = schedule.scheduleSummary;
        schemaAsset.AEHC_CRON_Job_Expression__c = schedule.cronExpression;
        
        if (schedule.frequency == 'Daily') {
            schemaAsset.AEHC_Time__c = convertStringToTime(schedule.scheduleTime);
        }
        
        if (schedule.frequency == 'Weekly') {
            schemaAsset.AEHC_Time__c = convertStringToTime(schedule.scheduleTime);
            
            if (schedule.weekdays != null && !schedule.weekdays.isEmpty()) {
                schemaAsset.AEHC_Weekdays__c = String.join(schedule.weekdays, ';');
            }
        }
        
        if (schedule.frequency == 'Multi-Weekly') {
            schemaAsset.AEHC_Time__c = convertStringToTime(schedule.scheduleTime);
            
            if (schedule.multiWeekWeeks != null && !schedule.multiWeekWeeks.isEmpty()) {
                schemaAsset.AEHC_Weeks__c = String.join(schedule.multiWeekWeeks, ';');
            }
            
            if (schedule.multiWeekDays != null && !schedule.multiWeekDays.isEmpty()) {
                schemaAsset.AEHC_Weekdays__c = String.join(schedule.multiWeekDays, ';');
            }
        }
        
        if (schedule.frequency == 'Monthly') {
            schemaAsset.AEHC_Time__c = convertStringToTime(schedule.scheduleTime);
            schemaAsset.AEHC_Day_of_Month__c = schedule.monthlyDay;
        }
        
        if (schedule.frequency == 'One-Time Load') {
            Time oneTimeExecutionTime = convertStringToTime(schedule.oneTimeTime);
            schemaAsset.AEHC_Time__c = oneTimeExecutionTime;
            schemaAsset.AEHC_One_Time_Execution_Time__c = oneTimeExecutionTime;
            
            if (String.isNotBlank(schedule.oneTimeDate)) {
                schemaAsset.AEHC_One_Time_Execution_Date__c =
                    Date.valueOf(schedule.oneTimeDate);
            }
        }
    }
    
    private static void applyDestinationToAsset(AEHC_Asset__c schemaAsset, DestinationWrapper destination) {
        if (destination == null) {
            return;
        }
        
        schemaAsset.AEHC_Storage_Account_Bucket__c = null;
        schemaAsset.AEHC_Container_Folder_Path__c = null;
        schemaAsset.AEHC_Output_Format__c = null;
        schemaAsset.AEHC_Blob_FileName__c = null;
        
        schemaAsset.AEHC_Database_Type__c = null;
        schemaAsset.AEHC_Host_Server__c = null;
        schemaAsset.AEHC_Port__c = null;
        schemaAsset.AEHC_JDBC_URL__c = null;
        schemaAsset.AEHC_Other_Properties__c = null;
        
        schemaAsset.AEHC_Remote_Directory_Path__c = null;
        schemaAsset.AEHC_Filename__c = null;
        schemaAsset.AEHC_Delimiter__c = null;
        
        
        schemaAsset.AEHC_Destination_Type__c = destination.destinationType;
        
        if (destination.destinationType == 'BLOB') {
            schemaAsset.AEHC_Storage_Account_Bucket__c = destination.storageAccount;
            schemaAsset.AEHC_Container_Folder_Path__c = destination.containerPath;
            schemaAsset.AEHC_Output_Format__c = destination.outputFormat;
            schemaAsset.AEHC_Blob_FileName__c = destination.blobFileName;
            schemaAsset.AEHC_Include_Header__c = destination.includeHeader;
            schemaAsset.AEHC_Provide_Custom_Header__c = destination.provideCustomHeader;
            schemaAsset.AEHC_Delimiter__c = destination.delimiter;
        }
        
        if (destination.destinationType == 'Database') {
            schemaAsset.AEHC_Database_Type__c = destination.databaseType;
            schemaAsset.AEHC_Host_Server__c = destination.databaseHost;
            schemaAsset.AEHC_Port__c = toDecimalOrNull(destination.databasePort);
            schemaAsset.AEHC_JDBC_URL__c = destination.jdbcUrl;
            schemaAsset.AEHC_Other_Properties__c = destination.otherProperties;
            schemaAsset.AEHC_Batch_Flag__c = destination.batchFlag;
            schemaAsset.AEHC_BatchSize__c = toDecimalOrNull(destination.batchSize);
            schemaAsset.AEHC_On_Initialization__c = destination.spOnInit;
            schemaAsset.AEHC_On_Load__c = destination.spOnLoad;
            schemaAsset.AEHC_On_Success__c = destination.spOnSuccess;
            schemaAsset.AEHC_On_Error__c = destination.spOnError;
            schemaAsset.AEHC_Mute_Error_Flag__c = destination.muteErrorFlag;
            schemaAsset.AEHC_Provide_Custom_Header__c = destination.provideCustomHeader;
        }
        
        if (destination.destinationType == 'SFTP') {
            schemaAsset.AEHC_Host_Server__c = destination.sftpHostName;
            schemaAsset.AEHC_Port__c = toDecimalOrNull(destination.sftpPort);
            schemaAsset.AEHC_Remote_Directory_Path__c = destination.sftpRemotePath;
            schemaAsset.AEHC_Filename__c = destination.sftpFileName;
            schemaAsset.AEHC_Output_Format__c = destination.sftpOutputFormat;
            schemaAsset.AEHC_Include_Header__c = destination.includeHeader;
            schemaAsset.AEHC_Provide_Custom_Header__c = destination.provideCustomHeader;
            schemaAsset.AEHC_Delimiter__c = destination.delimiter;
        }
    }

    /** Fetch DDH IntId using Application, Publication, Environment and Version*/
    public static String getIntId(Id applicationId, Id publicationId, String environment, String version, Boolean isSubscription, Id subscriptionId) {

        try {
            String query =
            'SELECT AEHC_IntId__c ' +
            'FROM AEHC_Asset__c ' +
            'WHERE AEHC_Application__c = :applicationId ' +
            'AND AEHC_Publication__c = :publicationId ' +
            'AND AEHC_Environment__c = :environment ' +
            'AND AEHC_Schema_Version__c = :version ' +
            'AND RecordType.DeveloperName = \'AEHC_Version\' ';

            if (isSubscription != null) {
                query += 'AND AEHC_Is_Subscription__c = :isSubscription ';
            }

            if (isSubscription == true && subscriptionId != null) {
                query += 'AND AEHC_Subscription_Request__c = :subscriptionId ';
            }

            query += 'LIMIT 1';

            List<AEHC_Asset__c> versions = Database.query(query);

            if (!versions.isEmpty() && String.isNotBlank(versions[0].AEHC_IntId__c)) {
                return versions[0].AEHC_IntId__c;
            }

        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'getIntId Error: ' + ex.getMessage());
        }

        // Never fail caller
        return '';
    }
    
    private static Decimal toDecimalOrNull(String value) {
        return String.isNotBlank(value)
            ? Decimal.valueOf(value)
            : null;
    }
    
    private static Id getRecordTypeIdByDeveloperName(Schema.SObjectType sObjectType, String developerName) {
        if (String.isBlank(developerName)) {
            throw new AuraHandledException('Required record type configuration is missing.');
        }
        
        Schema.RecordTypeInfo rtInfo =
            sObjectType.getDescribe()
            .getRecordTypeInfosByDeveloperName()
            .get(developerName);
        
        if (rtInfo == null) {
            throw new AuraHandledException('Required record type is missing.');
        }
        
        return rtInfo.getRecordTypeId();
    }
    
    public static Time convertStringToTime(String inputTime) {
        if (String.isBlank(inputTime)) {
            return null;
        }
        
        try {
            String cleanTime = inputTime.split('\\.')[0];
            List<String> parts = cleanTime.split(':');
            
            Integer hour = Integer.valueOf(parts[0]);
            Integer minute = parts.size() > 1 ? Integer.valueOf(parts[1]) : 0;
            Integer second = parts.size() > 2 ? Integer.valueOf(parts[2]) : 0;
            
            return Time.newInstance(hour, minute, second, 0);
            
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Invalid time format: ' + e.getMessage());
            return null;
        }
    }
    
    private static void logSaveErrors(Database.SaveResult result, String operation, Id relatedRecordId, String requestJson) {
        try {
            if (result == null || result.getErrors() == null) {
                return;
            }
            
            for (Database.Error err : result.getErrors()) {
                Map<String, Object> context = new Map<String, Object>{
                    'operation' => operation,
                        'statusCode' => String.valueOf(err.getStatusCode()),
                        'fields' => err.getFields(),
                        'requestJsonPresent' => String.isNotBlank(requestJson)
                        };
                            
                            AEHC_Logger.logError(
                                err.getMessage(),
                                COMPONENT_TYPE,
                                COMPONENT_NAME,
                                operation,
                                relatedRecordId != null ? String.valueOf(relatedRecordId) : null,
                                SEVERITY_P2,
                                CATEGORY_DML,
                                context,
                                getCurrentEnvironment()
                            );
            }
        } catch (Exception loggingException) {
            System.debug(LoggingLevel.ERROR, 'Failed to log save errors: ' + loggingException.getMessage());
        }
    }
    
    private static void logException(
        Exception ex,
        String operation,
        Id relatedRecordId,
        String requestJson
    ) {
        try {
            Map<String, Object> context = new Map<String, Object>{
                'operation' => operation,
                    'requestJsonPresent' => String.isNotBlank(requestJson)
                    };
                        
                        AEHC_Logger.logException(
                            ex,
                            COMPONENT_TYPE,
                            COMPONENT_NAME,
                            operation,
                            relatedRecordId,
                            SEVERITY_P2,
                            CATEGORY_SUBSCRIPTION,
                            context,
                            getCurrentEnvironment()
                        );
        } catch (Exception loggingException) {
            System.debug(LoggingLevel.ERROR, 'Failed to log exception: ' + loggingException.getMessage());
        }
    }
    
    private static String getCurrentEnvironment() {
        String domain = System.Url.getOrgDomainUrl().getHost().toLowerCase();
        
        if (domain.contains('sandbox') || domain.contains('--') || domain.contains('cs')) {
            if (domain.contains('dev') || domain.contains('--dev')) {
                return 'Dev';
            }
            
            if (domain.contains('qa') || domain.contains('--qa')) {
                return 'QA';
            }
            
            if (domain.contains('uat') || domain.contains('--uat')) {
                return 'UAT';
            }
            
            return 'Sandbox';
        }
        
        return 'Prod';
    }
    
    @AuraEnabled
    public static Map<String, Object> getUserApps(String userId, String searchKeywords) {
        Map<String, Object> response = new Map<String, Object>();
        try {
            if(String.isEmpty(userId)) userId = UserInfo.getUserId();
            
            Map<String, AEHC_Utility.LookupField> appId_appLookup = new Map<String, AEHC_Utility.LookupField>();
            
            List<User> users = [SELECT Id, ContactId, Contact.AEHC_App__c, Contact.AEHC_App__r.Id, Contact.AEHC_App__r.Name, Contact.AEHC_App__r.AEHC_Application_Id__c FROM User WHERE Id =:userId];
            
            if(!users.isEmpty() && !String.isEmpty(users[0].ContactId) && !String.isEmpty(users[0].Contact.AEHC_App__c)) {
                AEHC_Asset__c app = users[0].Contact.AEHC_App__r;
                appId_appLookup.put(app.Id, new AEHC_Utility.LookupField(app.Id, app.Name, app.AEHC_Application_Id__c));
            }
            
            // prepare filter
            List<String> filters = new List<String>();
            filters.add('AEHC_User__c = \'' + userId + '\'');
            filters.add('AEHC_Asset__r.AEHC_Is_Active__c = true');
            //if(!String.isEmpty(searchKeywords)) filters.add('(AEHC_Asset__r.AEHC_Application_Id__c LIKE \'%' + searchKeywords + '%\' OR AEHC_Asset__r.Name LIKE \'%' + searchKeywords + '%\')');
            
            // look into Salesforce
            String query = 'SELECT AEHC_Asset__c, AEHC_Asset__r.Name, AEHC_Asset__r.AEHC_Application_Id__c FROM AEHC_AssetMember__c WHERE ' + String.join(filters, ' AND ') + ' ORDER BY AEHC_Asset__r.Name ASC';
            
            // prepare response:data
            for(AEHC_AssetMember__c am : Database.query(query)) appId_appLookup.put(am.AEHC_Asset__c, new AEHC_Utility.LookupField(am.AEHC_Asset__c, am.AEHC_Asset__r.Name, am.AEHC_Asset__r.AEHC_Application_Id__c));
            
            if(appId_appLookup.isEmpty()) {
                response.put('status', 404);
                return response;
            }
            
            response.put('status', 200);
            response.put('data', appId_appLookup.values());
            return response;
            
        } catch(Exception e) {
            AEHC_Logger.logException(e, 'Apex', 'AEHC_ManageApplicationUserCtrl.getMembers', 'query', null, 'P1', null, null, AEHC_Utility.getCurrentEnvironment());
            response.put('status', 500);
            response.put('message', e.getMessage());
        }
        return response;
    }

    public static void sendResubmittedNotification(Id recipientUserId, Id targetRecordId, String versionName,String AEHC_Environment,
                                                                String AEHC_Schema_Version) {
        try {

            CustomNotificationType notificationType = [SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'AEHC_Subscription_Request_Submitted' LIMIT 1];
			String pageRef ='{"type":"comm__namedPage",' +
                            '"attributes":{"pageName":"manage-subscriptions"},' +
                            '"state":{' +
                            '"subscriptionId":"' + targetRecordId + '",' +
                            '"ver":"' + AEHC_Schema_Version + '",' +
                            '"env":"' + AEHC_Environment + '"' +
                            '}' +
                            '}';
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setTitle('Subscription Resubmitted');
            notification.setBody('Version "' + versionName +'" has been resubmitted for approval.');
            notification.setNotificationTypeId(notificationType.Id);
            notification.setTargetId(targetRecordId);            
			notification.setTargetPageRef(pageRef);
            Set<String> recipientIds = new Set<String>{ String.valueOf(recipientUserId)};
            notification.send(recipientIds);
            

        } catch (Exception ex) {
            System.debug('Failed to send notification: ' + ex.getMessage());
        }
    }
}