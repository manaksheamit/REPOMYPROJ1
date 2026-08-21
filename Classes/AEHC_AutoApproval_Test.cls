/*
 * @Author       Rushikesh Rajan Deshmukh
 * @CreatedDate  2026-05-23
 * @UpdatedDate  2026-06-12 */
@IsTest(seeAllData=true)
public class AEHC_AutoApproval_Test {

    /* =========================================================
       TEST 1 - MAIN FLOW
    ========================================================== */
    @IsTest
    static void testApprove_Main() {

        Account acc = new Account(Name = 'Auto Approval Test');
        insert acc;

        // Try submitting to approval (optional)
        try {
            Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
            req.setObjectId(acc.Id);
            req.setComments('Submitting');

            Approval.process(req);
        } catch (Exception e) {
            System.debug('Approval may not exist: ' + e.getMessage());
        }

        AEHC_AutoApproval.InputWrapper input = new AEHC_AutoApproval.InputWrapper();
        input.recordId = acc.Id;

        Test.startTest();
        AEHC_AutoApproval.approve(
            new List<AEHC_AutoApproval.InputWrapper>{input}
        );
        Test.stopTest();
    }

    /* =========================================================
       TEST 2 - MULTIPLE RECORDS
    ========================================================== */
    @IsTest
    static void testApprove_Multiple() {

        Account acc1 = new Account(Name = 'Test 1');
        Account acc2 = new Account(Name = 'Test 2');
        insert new List<Account>{acc1, acc2};

        AEHC_AutoApproval.InputWrapper input1 = new AEHC_AutoApproval.InputWrapper();
        input1.recordId = acc1.Id;

        AEHC_AutoApproval.InputWrapper input2 = new AEHC_AutoApproval.InputWrapper();
        input2.recordId = acc2.Id;

        Test.startTest();
        AEHC_AutoApproval.approve(
            new List<AEHC_AutoApproval.InputWrapper>{input1, input2}
        );
        Test.stopTest();
    }

    /* =========================================================
       TEST 3 - NULL INPUT (CATCH BLOCK)
    ========================================================== */
    @IsTest
    static void testApprove_Null() {

        AEHC_AutoApproval.InputWrapper input = new AEHC_AutoApproval.InputWrapper();
        input.recordId = null;

        Test.startTest();
        AEHC_AutoApproval.approve(
            new List<AEHC_AutoApproval.InputWrapper>{input}
        );
        Test.stopTest();
    }
}