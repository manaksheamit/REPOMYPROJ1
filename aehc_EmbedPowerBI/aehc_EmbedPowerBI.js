import { LightningElement, api, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import getEmbedInfo from '@salesforce/apex/AEHC_EmbedPowerBIController.getEmbedInfo';
import getAllConfigs from '@salesforce/apex/AEHC_EmbedPowerBIController.getAllConfigs';
import powerbiJS from '@salesforce/resourceUrl/powerbiJS';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class Aehc_EmbedPowerBI extends LightningElement {
    
    initialized = false;
    @track error;
    @track loading = false;
    @track reports = [];
    @track selectedReport = null;
    @api configName;
    @track showReports = true;   
    @track isLoadingReports = false;

    async connectedCallback() {
        try {
            await loadScript(this, powerbiJS);
            this.initialized = true;
            await this.loadAllReports();
        } catch (err) {
            this.error = 'Error loading Power BI JS Library: ' + err.message;
        }
    }

    async loadAllReports() {
        this.isLoadingReports = true;

        try {
            const configs = await getAllConfigs();
            this.reports = configs;
            this.selectedReport = null;
            this.updateReportButtonClasses();

        } catch (err) {
            this.showReports = false;
            this.error = null;
            console.error('loadAllReports Error:', err);
            this.showErrorToast(
                'Reports are currently unavailable for your user. Please contact your system administrator.'
            );
        } finally {
            this.isLoadingReports = false;
        }
    }

    async handleReportClick(event) {
       
            const reportName = event.currentTarget.dataset.name;
            this.selectedReport = reportName;
            this.updateReportButtonClasses();
            await this.embedReport(reportName);
       
    } 
    updateReportButtonClasses() {
        this.reports = this.reports.map((report) => {
            return {
                ...report,
                buttonClass:
                    report.name === this.selectedReport
                        ? 'menu-item menu-item-selected'
                        : 'menu-item'
            };
        });
   }   
    
    async embedReport(reportName) {   
        const container = this.template.querySelector('.powerbi-container');
        if (!container) {
            //this.error = 'Embed container not found in template.';
            return;
        }

        this.loading = true;
        try {
            const embedData = await getEmbedInfo({metaddataName: reportName});
            if (!embedData || !embedData.embedUrl || !embedData.embedToken) {
                throw new Error('Incomplete embed data returned from server.');
            }

            const config = {
                type: 'report',
                id: embedData.reportId,
                embedUrl: embedData.embedUrl,
                accessToken: embedData.embedToken,
                tokenType: 1,
                settings: {
                    panes: {
                        filters: { visible: false },
                        pageNavigation: { visible: false }
                    }
                }
            };

            try { window.powerbi.reset(container); } 
            catch (e) {}
            window.powerbi.embed(container, config);
            //this.error = null;
        } catch (err) {
                this.error = null;
                console.error('embedReport Error:', err);
                const container = this.template.querySelector('.powerbi-container');
                if (container && window.powerbi) {
                    try {
                        window.powerbi.reset(container);
                    } catch (e) {
                        console.error(e);
                    }
                }
                this.showErrorToast(`The selected report "${reportName}" could not be loaded. Please contact your system administrator.`);
            } finally {
            this.loading = false;
        }
    }
    showErrorToast(message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Unable to Load Report',
                message,
                variant: 'error'
            })
        );
    }
}