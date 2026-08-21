trigger AEHC_AccountCreationPETrigger on AEHC_AccountCreationRequest__e (after insert) {

    AEHC_AccountCreationPEHandler.process(Trigger.New);

}