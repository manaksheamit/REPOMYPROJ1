@IsTest
public class AEHC_Logger_Test {

   private static Map<String, Object> buildContext() {
        Map<String, Object> ctx = new Map<String, Object>();
        ctx.put('requestId', 'REQ-123');
        ctx.put('source', 'UnitTest');
        ctx.put('timestamp', System.now());
        return ctx;
    }

    @IsTest
    static void testLogException() {

        Exception ex;
        try {
            Integer x = 1 / 0; 
        } catch (Exception e) {
            ex = e;
        }

        Test.startTest();
        AEHC_Logger.logException(
            ex,
            'Apex',
            'AEHC_Logger_Test',
            'Create',
            '001000000000001',
            'P1',
            'DML',
            buildContext(),
            'QA'
        );
        Test.stopTest();

        List<AEHC_Error_Event__c> events =
            [SELECT Id, AEHC_Exception_Type__c, AEHC_Message__c, AEHC_Stacktrace__c
             FROM AEHC_Error_Event__c];

        System.assertEquals(1, events.size(), 'One error event should be logged');
        System.assertNotEquals(null, events[0].AEHC_Exception_Type__c);
        System.assertNotEquals(null, events[0].AEHC_Message__c);
    }

    
    @IsTest
    static void testLogError() {

        Test.startTest();
        AEHC_Logger.logError(
            'Custom validation failed',
            'Trigger',
            'AccountTrigger',
            'Create',
            '001000000000002',
            'P1',
            'Validation',
            buildContext(),
            'QA'
        );
        Test.stopTest();

        AEHC_Error_Event__c eventRec = new AEHC_Error_Event__c();
           eventRec = [SELECT AEHC_Exception_Type__c, AEHC_Message__c, AEHC_Category__c
             FROM AEHC_Error_Event__c
             LIMIT 1];

        System.assertEquals(
            AEHC_Constant.CUSTOM_ERROR,
            eventRec.AEHC_Exception_Type__c
        );
        System.assertEquals(
            'Custom validation failed',
            eventRec.AEHC_Message__c
        );
        System.assertEquals(
            'Validation',
            eventRec.AEHC_Category__c
        );
    }

    
    @IsTest
    static void testLogFromFlow() {

        AEHC_Logger.FlowInput input = new AEHC_Logger.FlowInput();
        input.message = 'Flow failed due to missing data';
        input.componentType = 'Flow';
        input.componentName = 'Account_Create_Flow';
        input.operation = 'Create';
        input.recordId = '001000000000003';
        input.severity = 'P2';
        input.category = 'Flow';
        input.transactionContextJson =
            JSON.serialize(buildContext());
        input.orgEnv = 'QA';

        List<AEHC_Logger.FlowInput> inputs = new List<AEHC_Logger.FlowInput>{ input };

        Test.startTest();
        AEHC_Logger.logFromFlow(inputs);
        Test.stopTest();

        List<AEHC_Error_Event__c> events =
            [SELECT AEHC_Exception_Type__c, AEHC_Message__c
             FROM AEHC_Error_Event__c];

        System.assertEquals(1, events.size());
        System.assertEquals(
            AEHC_Constant.FLOW_ERROR,
            events[0].AEHC_Exception_Type__c
        );
        System.assertEquals(
            'Flow failed due to missing data',
            events[0].AEHC_Message__c
        );
    }

    
    @IsTest
    static void testLogFromFlowWithInvalidJson() {

        AEHC_Logger.FlowInput input = new AEHC_Logger.FlowInput();
        input.message = 'Invalid JSON test';
        input.transactionContextJson = '{invalidJson:::';

        Test.startTest();
        AEHC_Logger.logFromFlow(new List<AEHC_Logger.FlowInput>{ input });
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT Count() FROM AEHC_Error_Event__c],
            'Record should still be inserted even with invalid JSON'
        );
    }
}