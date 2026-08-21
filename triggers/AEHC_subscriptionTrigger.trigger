/**
 * @description Trigger for Subscription__c.
 * Delegates all processing to AEHC_SubscriptionTriggerHandler.
 *
 * @author Himanshu Singh
 * @version 2.0
 */
trigger AEHC_subscriptionTrigger on Subscription__c (before insert,before update,after insert,after update) {

    // Prevent recursive execution
    if (AEHC_SubscriptionTriggerHandler.handleReccursion) {
        return;
    }

   AEHC_SubscriptionTriggerHandler.handleReccursion = true;

    // BEFORE EVENTS
    if (Trigger.isBefore) {

        if (Trigger.isInsert || Trigger.isUpdate) {
            AEHC_SubscriptionTriggerHandler.beforeUpsert(Trigger.new);
        }

    }

    // AFTER EVENTS
    if (Trigger.isAfter) {

        if (Trigger.isInsert) {
            //AEHC_SubscriptionTriggerHandler.createBusinessOwnerACR(Trigger.new);
            AEHC_SubscriptionTriggerHandler.afterInsert(Trigger.new);
        }

        if (Trigger.isUpdate) {
            AEHC_SubscriptionTriggerHandler.createAccountContactRelationship(Trigger.new,Trigger.oldMap);
        }
    }
}