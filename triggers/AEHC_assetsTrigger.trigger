/*@description This trigger runs on AEHC_Asset__c
 * @author Parvej Alam
 * @version 1.0
 */
trigger AEHC_assetsTrigger on AEHC_Asset__c (before insert, before update, before delete, after insert, after update, after delete, after undelete) {
	if (Trigger.isAfter) {

            // ✅ After Insert
            if (Trigger.isInsert) {
                AEHC_GroupCreationOnAssetHandler.accountCreation(trigger.new);
                AEHC_AssetsTriggerHandler.afterInsert(Trigger.new);                
            }

            // ✅ After Update
            if (Trigger.isUpdate) {
                AEHC_AssetsTriggerHandler.afterUpdate(Trigger.newMap, Trigger.oldMap);
            }
        }
}