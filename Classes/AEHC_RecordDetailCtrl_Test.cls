/**
 * @author Asif Ahmad
 * @date 26May2026
 * @description Test Class for AEHC_RecordDetailCtrl
*/
@IsTest
public class AEHC_RecordDetailCtrl_Test {

    @IsTest
    static void testGetRecord_Success() {
        // Create test data
        Contact acc = new Contact(LastName = 'Test Account');
        insert acc;

        Test.startTest();

        Map<String, Object> result = AEHC_RecordDetailCtrl.getRecord(
            'Contact',
            'Id, Name',
            'Id',
            acc.Id
        );

        Test.stopTest();
    }

    // Test: No matching record
    @IsTest
    static void testGetRecord_NoRecord() {
        Test.startTest();

        Map<String, Object> result = AEHC_RecordDetailCtrl.getRecord(
            'Account',
            'Id, Name',
            'Id',
            '001000000000000AAA' // fake Id
        );

        Test.stopTest();

        System.assertEquals(404, result.get('status'));
    }
    
    @IsTest
    static void testGetRecord_Exp() {
        Test.startTest();

        Map<String, Object> result = AEHC_RecordDetailCtrl.getRecord(
            'Account',
            'Id, Name1',
            'Id',
            '001000000000000AAA' // fake Id
        );

        Test.stopTest();

        System.assertEquals(500, result.get('status'));
    }
}