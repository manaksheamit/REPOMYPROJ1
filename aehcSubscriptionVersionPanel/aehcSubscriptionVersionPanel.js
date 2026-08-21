import { LightningElement, api, wire } from 'lwc';
import L_APPROVALHISTORY from '@salesforce/label/c.AEHC_ApprovalHistory';
import getJobSubmonStatus from '@salesforce/apex/AEHC_EnableDisableSubJob.getJobSubmonStatus';
import enableDisableSubMonJob from '@salesforce/apex/AEHC_EnableDisableSubJob.enableDisableSubMonJob';
import getVersionId from '@salesforce/apex/AEHC_VersionHistoryController.getVersionId';
import showHideButton from '@salesforce/apex/AEHC_RoleBaseBtnVisibility.ButtonVisibility';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class AehcSubscriptionVersionPanel extends LightningElement {

    @api environmentOptions = [];
    @api selectedEnvironment;

    @api versionOptions = [];
    @api selectedVersion;

    @api versionData;
    @api isLoading;
    @api disableEdit;
    showPromoteModal = false;
    @api subscriptionId;
    @api recordId;

    labels = {
        approvalhistory: L_APPROVALHISTORY
    };

    isSubmon = false;
    isEnabled = false;
    showModal = false;
    actionType;

    versionId;
    previousState;

    isHideButton = false;

    @wire(showHideButton)
    wiredData({ data, error }) {
        if (data !== undefined) {
            this.isHideButton = data;
        } else if (error) {
            this.isShowButton = false;
            console.error('Button visibility error:', error);
        }
    }

    async fetchVersionId() {
        try {

            const data = await getVersionId({
                subId: this.subscriptionId,
                env: this.selectedEnvironment,
                version: this.selectedVersion
            });

            this.versionId = data;
            console.log('@@@ versionId', this.versionId);
        } catch (error) {
            console.error('Error fetching version', error);
        }
    }

    async connectedCallback() {
        try {
            await this.fetchVersionId(); // ensures value is set before wire reacts

            // Call Apex imperatively
            const data = await getJobSubmonStatus({ recordId: this.versionId });
            if (data) {
                this.isSubmon = data.isSubmon;
                this.isEnabled = data.isEnabled;
            }
        } catch (error) {
            this.isSubmon = false;
            this.isEnabled = false;
        }

    }

    handleEnvChange(event) {
        this.dispatchEvent(new CustomEvent('envchange', {
            detail:
            {
                value: event.detail.value
            }
        }));
    }

    showPromoteModal = false;
    handlePromote() {
        this.showPromoteModal = true;
    }
    closePromoteModel() {
        this.showPromoteModal = false;
    }
    handleVersionChange(event) {
        this.dispatchEvent(new CustomEvent('versionchange', {

            detail: {
                value: event.detail.value   // ✅ FIX HERE
            }

        }));
    }

    handleChangeHistory() {
        this.dispatchEvent(new CustomEvent('changehistory'));
    }

    get envOptions() {
        return (this.environmentOptions || []).map(e => ({
            label: e,
            value: e
        }));
    }
    handleEdit() {
        this.dispatchEvent(new CustomEvent('edit'));
    }

    get frequency() {
        return this.versionData?.schedule?.frequency || '';
    }

    get isSFTP() {
        return this.versionData?.destination?.destinationType === 'SFTP';
    }

    get isDatabase() {
        return this.versionData?.destination?.destinationType === 'Database';
    }

    get isBlob() {
        return this.versionData?.destination?.destinationType === 'BLOB';
    }
    get isTransformationRequired() {
        return this.versionData?.transformationRequired;
    }
    get transformationId() {
        return this.versionData?.transformationId;
    }

    get selectedFieldsJson() {
        return JSON.stringify(this.versionData?.selectedFieldsJson || []);
    }

    get weekdays() {
        return (this.versionData?.schedule?.weekdays || []).join(', ');
    }

    get isFrequencyDaily() {
        return this.versionData?.schedule?.frequency === 'Daily';
    }

    get isFrequencyWeekly() {
        return this.versionData?.schedule?.frequency === 'Weekly';
    }

    get isFrequencyMonthly() {
        return this.versionData?.schedule?.frequency === 'Monthly';
    }

    get isFrequencyMultiWeekly() {
        return this.versionData?.schedule?.frequency === 'Multi-Weekly';
    }
    get isFrequencyOneTime() {
        return this.versionData?.schedule?.frequency === 'One-Time Load';
    }

    get multiWeekWeeks() {
        return (this.versionData?.schedule?.multiWeekWeeks || []).join(', ');
    }

    get multiWeekDays() {
        return (this.versionData?.schedule?.multiWeekDays || []).join(', ');
    }

    get includeHeader() {
        return this.versionData?.destination?.includeHeader;
    }

    get provideCustomHeader() {
        return this.versionData?.destination?.provideCustomHeader;
    }

    // Disable Promote Button if Selected Environment is Production
    get disablePromoteButton() {
        return this.selectedEnvironment === 'Production';
    }

    // Show buttons only if Submon
    get showButtons() {
        return this.isSubmon;
    }

    // Optional: keep same modal message logic
    get modalMessage() {
        return this.actionType === 'disable'
            ? 'Are you sure you want to disable the subscription job?'
            : 'Are you sure you want to enable the subscription job?';
    }
    get showDelimeter(){
        const isDestination = this.versionData?.destination;
        const outputXMLFormat = isDestination?.outputFormat || isDestination?.sftpOutputFormat;
        return outputXMLFormat.toLowerCase() === 'xml' ? false : true;
        
    }

    handleToggle(event) {
        const isChecked = event.target.checked;

        // Save previous state BEFORE change
        this.previousState = this.isEnabled;

        // Temporarily update UI (optional, or remove depending UX)
        this.isEnabled = isChecked;

        // Determine action
        this.actionType = isChecked ? 'enable' : 'disable';

        // Show modal
        this.showModal = true;
    }
    handlePromoteComplete(event) {

        this.showPromoteModal = false;

        this.dispatchEvent(
            new CustomEvent('envchange', {
                detail: event.detail.environment
            })
        );

        this.dispatchEvent(
            new CustomEvent('versionchange', {
                detail: {
                    value: event.detail.version
                }
            })
        );
    }

    closeModal() {
        this.showModal = false;
        // ✅ Revert toggle back to original state
        this.isEnabled = this.previousState;

    }

    async confirmAction() {
        try {
            // const newStatus = this.actionType === 'enable' ? 'Active' : 'Inactive';
            const newStatus = this.actionType === 'enable'; // ✅ Boolean
            const res = await enableDisableSubMonJob({
                recordId: this.versionId,
                activeFlag: newStatus
            });

            this.showModal = false;
            // window.location.reload();
            // ✅ Check Apex return value
            if (res === true) {
                this.showToast(
                    'Success',
                    this.actionType === 'enable'
                        ? 'Job enabled successfully'
                        : 'Job disabled successfully',
                    'success'
                );

                this.showModal = false;

                // Optional: update UI without reload
                this.isEnabled = this.actionType === 'enable';

                // If you really need reload
                //window.location.reload();
            }
            else {
                // ✅ Handle false response
                this.showToast(
                    'Error',
                    'Operation failed. Please try again.',
                    'error'
                );

                // Revert toggle state
                this.isEnabled = this.previousState;
                this.showModal = false;
            }



        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error occurred', 'error');

            // ✅ Revert toggle on error
            this.isEnabled = this.previousState;
            this.showModal = false;

        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
    get isSubmonSchedule() {
        return this.versionData?.schedule?.schedulerMode === 'Submon (Triggered on Publication Completion)';
    }
}