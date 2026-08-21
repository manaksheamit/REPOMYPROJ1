import { LightningElement, api, track, wire } from 'lwc';
import getDevActivePublicationData from '@salesforce/apex/AEHC_PublicationController.getDevActivePublicationData';
import updatePublicationAdvanced from '@salesforce/apex/AEHC_PublicationController.updatePublicationAdvanced';
import getDescriptionMaxLimit from '@salesforce/apex/AEHC_PublicationController.getDescriptionMaxLimit';

export default class AehcEditPublicationModal extends LightningElement {

    @api publicationId;
    @api picklistOptions;
     @track schemaName;
    @track tableName;

    @wire(getDescriptionMaxLimit) descLimit;

    @track applicationId;
    @track applicationName;
    @track publicationPublicId;
    @track isScheduleReady = false;
    recordTypeId;
    isSaving = false;

    selectedType = 'BASIC';

    editTypes = [
        { label: 'Basic Details Change', value: 'BASIC' },
        { label: 'Schedule Change', value: 'SCHEDULE' },
        { label: 'GP Schema Change Request', value: 'SCHEMA' }
    ];

    // ✅ BASIC
    publicationName;
    description;
    originalBasic = {};

    // ✅ SCHEDULE
    @track wizardData = {
        schedule: {
            schedulerMode: '',
            frequency: '',
            scheduleTime: '',
            weekdays: [],
            multiWeekWeeks: [],
            multiWeekDays: [],
            monthlyDay: '',
            oneTimeDate: '',
            oneTimeTime: '',
            scheduleSummary: '',
            cronExpression: ''
        }
    };

    originalSchedule = '';

    // ✅ SCHEMA
    schemaDescription = '';

    // ✅ GETTERS
    get isBasic() {
        return this.selectedType === 'BASIC';
    }

    get isSchedule() {
        return this.selectedType === 'SCHEDULE';
    }

    get isSchema() {
        return this.selectedType === 'SCHEMA';
    }

    connectedCallback() {
        this.loadData();
    }

    async loadData() {
        const data = await getDevActivePublicationData({
            publicationId: this.publicationId
        });

        // ✅ BASIC
        this.publicationName = data.publicationName;
        this.description = data.description;
        this.applicationName = data.applicationName;
        this.applicationId = data.applicationId;
        this.schemaName = data.schemaName;
        this.tableName = data.tableName;
        
        this.originalBasic = {
            name: this.publicationName,
            desc: this.description,
            applicationId: this.applicationId,
            applicationName: this.applicationName
        };
        console.log('data' + JSON.stringify(data.schedule));
        // ✅ SCHEDULE (fallback already handled in apex)
        if (data.schedule) {
            this.wizardData = JSON.parse(JSON.stringify({
                ...this.wizardData,

                schedule: {
                    schedulerMode: data.schedule?.schedulerMode || '',
                    frequency: data.schedule?.frequency || '',
                    scheduleTime:
                        data.schedule?.scheduleTime && data.schedule.scheduleTime !== '0'
                            ? data.schedule.scheduleTime
                            : '',
                    weekdays: data.schedule?.weekdays
                        ? data.schedule.weekdays.split(';')
                        : [],
                    multiWeekWeeks: data.schedule?.multiWeekWeeks || [],
                    multiWeekDays: data.schedule?.multiWeekDays || [],
                    monthlyDay: data.schedule?.monthlyDay || '',
                    oneTimeDate: data.schedule?.oneTimeDate || '',
                    oneTimeTime: data.schedule?.oneTimeTime || '',
                    scheduleSummary: data.schedule?.scheduleSummary || '',
                    cronExpression: data.schedule?.cronExpression || ''
                }
            }));
            this.wizardData = { ...this.wizardData };
            this.originalSchedule = JSON.stringify(this.wizardData.schedule);
            this.isScheduleReady = true;
        }
    }

    normalizeSchedule(data) {
        return {
            schedule: {   // ✅ IMPORTANT FIX
                schedulerMode: data.schedulerMode,
                frequency: data.frequency,
                scheduleTime: data.scheduleTime,
                weekdays: data.weekdays ? data.weekdays.split(';') : [],
                multiWeekWeeks: [],
                multiWeekDays: [],
                monthlyDay: data.monthlyDay,
                cronExpression: data.cronExpression,
                scheduleSummary: data.scheduleSummary || ''
            }
        };
    }

    handleTypeChange(e) {
        this.selectedType = e.detail.value;

        if (this.selectedType === 'SCHEDULE') {
            this.isScheduleReady = false;

            // ✅ force re-render
            setTimeout(() => {
                this.isScheduleReady = true;
            }, 0);
        }
    }

    handleNameChange(e) {
        this.publicationName = e.target.value;
    }

    handleDescChange(e) {
        this.description = e.target.value;
    }

    handleSchemaChange(e) {
        this.schemaDescription = e.target.value;
    }



    handleScheduleChange(e) {
        this.wizardData = {
            ...this.wizardData,
            schedule: {
                ...e.detail.schedule
            }
        };
    }



    // ✅ SUBMIT ENABLE LOGIC
    get isSubmitDisabled() {

        
if (this.isSaving) {
        return true;
    }


        if (this.selectedType === 'BASIC') {
            return (
                this.publicationName === this.originalBasic.name &&
                this.description === this.originalBasic.desc
            );
        }

        if (this.selectedType === 'SCHEDULE') {
            return JSON.stringify(this.wizardData.schedule) === this.originalSchedule;
        }

        if (this.selectedType === 'SCHEMA') {
            return !this.schemaDescription?.trim();
        }

        return true;
    }

    async handleSubmit() {

        
if (this.isSaving) {
        return;
    }

  this.isSaving = true;

        let payload = {};

        if (this.selectedType === 'BASIC') {
            payload = {
                name: this.publicationName,
                description: this.description
            };
        }

        if (this.selectedType === 'SCHEDULE') {
            payload = this.wizardData.schedule;
        }

        if (this.selectedType === 'SCHEMA') {
            payload = {
                schemaRequest: this.schemaDescription
};
        }

        try {
            const result = await updatePublicationAdvanced({
                publicationId: this.publicationId,
                type: this.selectedType,
                payloadJson: JSON.stringify(payload)
            });

            // ✅ HANDLE RESPONSE
            if (result?.success) {

                // ✅ show message from backend
                this.dispatchEvent(new CustomEvent('success', {
                    detail: {
                        message: result.message,
                        type: this.selectedType
                    }
                }));

                this.handleClose();

            } else {
                this.showError(result?.message || 'Update failed');
            }

        } catch (error) {
            this.showError(error);
        } finally {
             this.isSaving = false;
        }
    }


    showError(error) {

        let message = error?.body?.message || error?.message || 'Unknown error';

        this.dispatchEvent(new CustomEvent('error', {
            detail: { message }
        }));

        console.error('Update Error:', message);
    }


    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }
}