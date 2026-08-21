import { LightningElement, track, wire, api } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';

import getAsset from '@salesforce/apex/AEHCAssetDetailController.getAssets';
import getFieldsFromApi from '@salesforce/apex/AEHCAssetDetailController.getFieldsFromApi';
import getPublicationContacts from '@salesforce/apex/AEHCAssetDetailController.getPublicationContacts';
import logError from '@salesforce/apex/AEHC_Logger.logError';
import APP_ICON from '@salesforce/resourceUrl/AEHC_App_Id';
import PUB_ICON from '@salesforce/resourceUrl/AEHC_Pub_Id';
import PUBTYPE_ICON from '@salesforce/resourceUrl/AEHC_PubType';
import SCHEDULE_ICON from '@salesforce/resourceUrl/AEHC_Schedule';
import TABLEERROR_LABEL from '@salesforce/label/c.AEHC_Publication_Error';
import AEHC_Application_ID from '@salesforce/label/c.AEHC_Application_ID';
import AEHC_DP_PubId from '@salesforce/label/c.AEHC_DP_PubId';
import AEHC_Publication_Type from '@salesforce/label/c.AEHC_Publication_Type';
import AEHC_Publication_Description from '@salesforce/label/c.AEHC_Publication_Description';
import AEHC_DP_Environment from '@salesforce/label/c.AEHC_DP_Environment';
import AEHC_DP_SchemaVersion from '@salesforce/label/c.AEHC_DP_SchemaVersion';
import AEHC_DP_DataType from '@salesforce/label/c.AEHC_DP_DataType';
import AEHC_DP_Description from '@salesforce/label/c.AEHC_DP_Description';
import AEHC_DP_FileName from '@salesforce/label/c.AEHC_DP_FileName';
import AEHC_DP_Required from '@salesforce/label/c.AEHC_DP_Required';

export default class AehcAssetDetail extends LightningElement {

    assetId;
    asset;
    isChangeHistory = false;
    appIcon = APP_ICON;
    pubIcon = PUB_ICON;
    pubTypeIcon = PUBTYPE_ICON;
    scheduleIcon = SCHEDULE_ICON;
    //Labels
    applicationId = AEHC_Application_ID;
    publicationId = AEHC_DP_PubId;
    publicationType = AEHC_Publication_Type;
    publicationDescription = AEHC_Publication_Description;
    environmentLabel = AEHC_DP_Environment;
    versionLabel = AEHC_DP_SchemaVersion;
    dataTypeLabel = AEHC_DP_DataType;
    descriptionLabel = AEHC_DP_Description;
    fileNameLabel = 'Field Name';
    requiredLabel = AEHC_DP_Required;

    @track rows = [];
    @track contacts = [];

    totalRecords = 0;
    limit = 5;
    offset = 0;
    showLoadMore = true;

    // TABLE‑ONLY STATE (IMPORTANT)
    isTableLoading = false;
    tableError = '';
    hasTableError = false;

    @api selectedEnvironment = 'Dev';
    @api environmentOptions;
    _descriptionChange;

    @api
    set descriptionChange(value) {
        this._descriptionChange = value;
        if (value) {
            this.init();
        }
    }

    get descriptionChange() {
        return this._descriptionChange;
    }

    @wire(CurrentPageReference)
    handlePageRef(ref) {
        if (ref?.state?.id) {
            this.assetId = ref.state.id;
            this.selectedEnvironment = ref.state.env ? ref.state.env : 'Dev';
            console.log('this.selectedEnvironment', this.selectedEnvironment);
            this.init();
        }
    }
    response;
    async init() {
        this.response = await getAsset({ assetId: this.assetId, env: this.selectedEnvironment });
        this.asset = this.response.assets;
        console.log(this.asset);
        this.environmentOptions = [];

        this.environmentOptions = this.response.environments.map(e => ({
            label: e,
            value: e
        }));


        this.selectedEnvironment = this.asset?.environment;
        console.log('Event log'+this.asset.status);
       this.dispatchEvent(
            new CustomEvent('statuschange', {  
                detail:{
                active : this.asset.status
                }
            })
        );
         console.log('Event log');
        //this.loadFields(true);
        this.loadContacts();
    }

    async loadFields(reset) {
        if (reset) {
            this.rows = [];
            this.offset = 0;
            this.showLoadMore = true;
        }

        //ONLY TABLE LOADING
        //this.isTableLoading = true;
        this.hasTableError = false;
        this.tableError = '';

        try {
            const res = await getFieldsFromApi({
                assetId: this.assetId,
                environment: this.selectedEnvironment,
                limitSize: this.limit,
                offsetSize: this.offset
            });

            this.rows = [...this.rows, ...res.records];
            this.totalRecords = res.totalRecords;
            this.offset += this.limit;

            this.showLoadMore = this.rows.length < this.totalRecords;

        } catch (error) {

            await logError({
                message: error?.body?.message || 'Table load failed',
                componentType: 'LWC',
                componentName: 'AehcAssetDetail',
                operation: 'loadFields',
                recordId: this.assetId,
                severity: 'P2',
                category: 'UI',
                transactionContext: { environment: this.selectedEnvironment },
                orgEnv: this.selectedEnvironment
            });

            this.hasTableError = true;
            this.tableError = TABLEERROR_LABEL;
            this.showLoadMore = false;

        } finally {
            this.isTableLoading = false;
        }
    }

    loadMore() {
        this.loadFields(false);
    }

    async handleEnvironmentChange(event) {
        this.selectedEnvironment = event.detail.value;

        this.response = await getAsset({
            assetId: this.assetId,
            env: this.selectedEnvironment
        });

        this.asset = this.response.assets;

        this.environmentOptions = this.response.environments.map(e => ({
            label: e,
            value: e 
        }));

        this.dispatchEvent(
            new CustomEvent('envchange', {
                detail:{selectedEnvironment: this.selectedEnvironment,
                active : this.asset.status
                }
            })
        );

        this.loadFields(true);
    }
    get historyRecordId() {
        return this.asset?.versionId;
    }

    async loadContacts() {
        const data = await getPublicationContacts({ assetId: this.assetId });
        this.contacts = data.map(c => ({
            ...c,
            initials: c.name ? c.name.charAt(0) : ''
        }));
    }

    // TABLE UI HELPERS
    get showTable() {
        return !this.isTableLoading && !this.hasTableError && this.rows.length > 0;
    }

    get showNoData() {
        return !this.isTableLoading && !this.hasTableError && this.rows.length === 0;
    }

    handleChangeHistory() {
        this.isChangeHistory = true;
    }

    closeChangeHistoryModal() {
        this.isChangeHistory = false;
    }
}