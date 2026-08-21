trigger AEHC_SubscriptionAPITrigger on Subscription__c (after update) {

    if (Trigger.isAfter && Trigger.isUpdate) {
        AEHC_SubscriptionAPITriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }

}