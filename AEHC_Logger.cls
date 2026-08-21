/*@description This class is for Error and exception logging.
 * It includes methods for creating Error Event records.
 * @author Himanshu
 * @version 1.0
 */

public with sharing class AEHC_Logger {

    /* Method for Exception in apex
     * 
     */ 
    
    public static void logException(
        Exception ex,
        String componentType,
        String componentName,
        String operation,
        String recordId,
        String severity,
        String category,
        Map<String, Object> transactionContext,
        String orgEnv
    ) {
        try {
            AEHC_Error_Event__c eventRec = buildBaseRecord(
                componentType,
                componentName,
                operation,
                recordId,
                severity,
                category,
                transactionContext,
                orgEnv
            );

            eventRec.AEHC_Exception_Type__c = ex.getTypeName();
            eventRec.AEHC_Message__c        = ex.getMessage();
            eventRec.AEHC_Stacktrace__c     = ex.getStackTraceString();
            eventRec.AEHC_Line_Number__c    = extractLineNumber(ex);

            insert eventRec;
        } catch (Exception ignore) {
            
            System.debug('AEHC Logger failed: ' + ignore.getMessage());
        }
    }

    /* Method used to log when custom error used in apex 
     */ 
    @AuraEnabled
    public static void logError(
        String message,
        String componentType,
        String componentName,
        String operation,
        String recordId,
        String severity,
        String category,
        Map<String, Object> transactionContext,
        String orgEnv
    ) {
        try {
            AEHC_Error_Event__c eventRec = buildBaseRecord(
                componentType,
                componentName,
                operation,
                recordId,
                severity,
                category,
                transactionContext,
                orgEnv
            );

            eventRec.AEHC_Exception_Type__c = AEHC_Constant.CUSTOM_ERROR;
            eventRec.AEHC_Message__c        = message;

            insert eventRec;
        } catch (Exception ignore) {
            System.debug('AEHC Logger failed: ' + ignore.getMessage());
        }
    }

    
    public class FlowInput {

        @InvocableVariable(required=true)
        public String message;

        @InvocableVariable
        public String componentType;

        @InvocableVariable
        public String componentName;

        @InvocableVariable
        public String operation;

        @InvocableVariable
        public String recordId;

        @InvocableVariable
        public String severity;

        @InvocableVariable
        public String category;

        
        @InvocableVariable
        public String transactionContextJson;
        
        @InvocableVariable
        public String orgEnv;
    }

    @InvocableMethod(
        label='Log Error Event'
        description='Create Error Event record for Apex or Flow errors'
    )
    public static void logFromFlow(List<FlowInput> inputs) {

        List<AEHC_Error_Event__c> records = new List<AEHC_Error_Event__c>();

        for (FlowInput input : inputs) {
            try {
                AEHC_Error_Event__c eventRec = buildBaseRecord(
                    input.componentType,
                    input.componentName,
                    input.operation,
                    input.recordId,
                    input.severity,
                    input.category,
                    parseJson(input.transactionContextJson),
                    input.orgEnv
                );

                eventRec.AEHC_Exception_Type__c = AEHC_Constant.FLOW_ERROR;
                eventRec.AEHC_Message__c        = input.message;

                records.add(eventRec);
            } catch (Exception ignore) {
                System.debug('Flow logging failed');
            }
        }

        if (!records.isEmpty()) {
            insert records;
        }
    }

    
    private static AEHC_Error_Event__c buildBaseRecord(
        String componentType,
        String componentName,
        String operation,
        String recordId,
        String severity,
        String category,
        Map<String, Object> context,
        String orgEnv
    ) {
        AEHC_Error_Event__c eventRec = new AEHC_Error_Event__c();

        // What failed
        eventRec.AEHC_Component_Type__c = componentType;
        eventRec.AEHC_Component_Name__c = componentName;
        eventRec.AEHC_Operation__c      = operation;

        // Context
        eventRec.AEHC_Record_Id__c  = recordId;
        eventRec.AEHC_User__c       = UserInfo.getUserId();
        eventRec.AEHC_Profile__c    = UserInfo.getProfileId();
        eventRec.AEHC_Running_As__c = getExecutionType();
        eventRec.AEHC_Is_Async__c   = isAsync();

        if (context != null) {
            eventRec.AEHC_Transaction_Context__c = JSON.serialize(context);
        }

        
        eventRec.AEHC_Severity__c    = severity;
        eventRec.AEHC_Category__c    = String.isBlank(category) ? AEHC_Constant.CATEGORY_UNKNOWN : category;
        eventRec.AEHC_Status__c      = AEHC_Constant.STATUS_NEW;
        eventRec.AEHC_Environment__c = orgEnv;
       

        return eventRec;
    }

    private static Boolean isAsync() {
        return System.isBatch() ||
               System.isFuture() ||
               System.isQueueable() ||
               System.isScheduled();
    }

    private static String getExecutionType() {
        if (System.isBatch())      return AEHC_Constant.BATCH_APEX;
        if (System.isQueueable())  return AEHC_Constant.QUEUEABLE_APEX;
        if (System.isFuture())     return AEHC_Constant.FUTURE_APEX;
        if (System.isScheduled())  return AEHC_Constant.SCEHEDULED_APEX;
        return AEHC_Constant.SCEHEDULED_APEX;
    }

    

    private static Integer extractLineNumber(Exception ex) {
        try {
            String stack = ex.getStackTraceString();
            if (stack != null && stack.contains('line')) {
                String num = stack.substringAfter('line ').substringBefore(',');
                return Integer.valueOf(num);
            }
        } catch (Exception ignore) {}
        return null;
    }

    private static Map<String, Object> parseJson(String jsonString) {
        if (String.isBlank(jsonString)) return null;
        try {
            return (Map<String, Object>) JSON.deserializeUntyped(jsonString);
        } catch (Exception e) {
            return null;
        }
    }
}