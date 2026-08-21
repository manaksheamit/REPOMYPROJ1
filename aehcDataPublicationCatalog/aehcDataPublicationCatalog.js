/**
 * Component: aehcDataPublicationCatalog
 * Author: Umang Rohitbhai Fofariya
 * Date: 24-May-2026
 *
 * Description:
 * Displays a searchable and filterable catalog of data publications
 * with infinite scrolling, application filters, and navigation to
 * publication details, manage application, and create publication flows.
 */
import { LightningElement, track, api, wire } from "lwc";
import logError from "@salesforce/apex/AEHC_Logger.logError";
import fetchAssets from "@salesforce/apex/AEHC_DataPublicationCatalogController.fetchAssets";
import fetchApplicationFilters from "@salesforce/apex/AEHC_DataPublicationCatalogController.fetchApplicationFilters";
import getFiltersApex from "@salesforce/apex/AEHC_DataPublicationCatalogController.getFilters";
import showHideButton from '@salesforce/apex/AEHC_RoleBaseBtnVisibility.ButtonVisibility';
import { NavigationMixin } from 'lightning/navigation'

// Custom Labels
import LABEL_TITLE from "@salesforce/label/c.AEHC_Carousel_Title";
import LABEL_DESC from "@salesforce/label/c.AEHC_Carousel_Description";
import LABEL_ERROR_TITLE from "@salesforce/label/c.AEHC_Carousel_Error_Title";
import LABEL_ERROR_DESC from "@salesforce/label/c.AEHC_Carousel_Error_Description";
import LABEL_EMPTY_TITLE from "@salesforce/label/c.AEHC_Carousel_Empty_Title";
import LABEL_EMPTY_DESC from "@salesforce/label/c.AEHC_Carousel_Empty_Description";
import LABEL_ENV_NAME from "@salesforce/label/c.AEHC_Environment_Name";
import LABEL_NO_FILTERED_DATA from "@salesforce/label/c.AEHC_Carousel_NoDataFilter";
import LABEL_SEARCH_PLACEHOLDER from "@salesforce/label/c.AEHC_Search_Placeholder";
import LABEL_CLEAR_ALL from "@salesforce/label/c.AEHC_Clear_All";
import LABEL_FILTERS from "@salesforce/label/c.AEHC_Filters";
import LABEL_ADJUST_FILTERS_HELP from "@salesforce/label/c.AEHC_Adjust_Filters_Help";


export default class AehcDataPublicationCatalog extends NavigationMixin(LightningElement) {
  @api isPreview = false;

  searchKey = "";
  selectedApplication = "";
  selectedEnvironment = 'Dev';

  @track displayedRecords = [];
  isLoading = false;
  @track skeletonArray = [1, 2, 3, 4, 5, 6, 7, 8, 9];
  showScrollTop = false;
  filtersOpen = false;
  hasError = false;

  loadBatch = 9;
  debounceTimeout;
  columnColors = ["#2ECC71", "#9B59B6", "#3498DB"];
  offset = 0;
  pageSize = 9;
  hasMoreData = true;

  applicationOptions = [];
  envOptions = [];
  scrollThreshold = 50;
  isHideButton = false;
  
  labels = {
    title: LABEL_TITLE,
    description: LABEL_DESC,
    errorTitle: LABEL_ERROR_TITLE,
    errorDesc: LABEL_ERROR_DESC,
    emptyTitle: LABEL_EMPTY_TITLE,
    emptyDesc: LABEL_EMPTY_DESC,
    noFilteredData: LABEL_NO_FILTERED_DATA,
    searchPlaceholder: LABEL_SEARCH_PLACEHOLDER,
    clearAll: LABEL_CLEAR_ALL,
    filters: LABEL_FILTERS,
    adjustFiltersHelp: LABEL_ADJUST_FILTERS_HELP
  };

  connectedCallback() {
    try {
      this.readUrlParams();
      this.loadFilters();
      this.loadMoreRecords();
      this.boundHandleScroll = this.handleScroll.bind(this);
      window.addEventListener('scroll', this.boundHandleScroll);

    } catch (e) {
      this.hasError = true;
      this.logExceptionToApex(e, "connectedCallback");
    }
  }

  async loadFilters() {
    try {
      const apps = await fetchApplicationFilters();
      this.applicationOptions = [
        { label: "All Applications", value: "" },
        ...apps.map((a) => ({ label: a, value: a }))
      ];

      const filterResponse = await getFiltersApex();
      if(filterResponse.status == 200) {
        this.envOptions = [
          { label: "All Environments", value: "" },
          ...filterResponse.data.Environment
        ];
      }

    } catch (e) {
      this.hasError = true;
    }
  }

  @wire(showHideButton)
    wiredData({ data, error }) {
        if (data !== undefined) {
            this.isHideButton = data;
        } else if (error) {
            this.isShowButton = false;
            console.error('Button visibility error:', error);
        }
    }

  disconnectedCallback() {
    window.removeEventListener('scroll', this.boundHandleScroll);
  }

  initializeFilters() {
    const appSet = new Set(this.allRecords.map((r) => r.application));
    this.applicationOptions = [
      { label: "All Applications", value: "" },
      ...Array.from(appSet).map((a) => ({ label: a, value: a }))
    ];
  }

  handleCreatePublication() {
    window.location.href = "/aeh/s/manage-publication";
  }

  handleManageApplication() {
    window.location.href = "/aeh/s/manage-application";
  }

  readUrlParams() {
    if (this.isPreview) return;
    try {
      const url = new URL(window.location.href);
      this.searchKey = url.searchParams.get("search") || "";
      this.selectedApplication = url.searchParams.get("application") || "";
      this.selectedEnvironment = url.searchParams.get("environment") || "";
    } catch (e) {
      this.hasError = true;
    }
  }

  updateUrl() {
    if (this.isPreview) return;
    const params = new URLSearchParams();
    if (this.searchKey) params.set("search", this.searchKey);
    if (this.selectedApplication)
      params.set("application", this.selectedApplication);
    if(this.selectedEnvironment) params.set('environment', this.selectedEnvironment);

    const qs = params.toString();
    const newUrl = qs
      ? `?${qs}`
      : window.location.pathname + window.location.hash;

    window.history.replaceState({}, '', newUrl);

  }
handleManagePublication() {
    this[NavigationMixin.Navigate]({
        type: 'standard__objectPage',
        attributes: {
            objectApiName: 'AEHC_Asset__c',
            actionName: 'list'
        }
    });
}

  resetAndReload() {
    this.displayedRecords = [];
    this.offset = 0;
    this.hasMoreData = true;
    this.hasError = false;
    this.loadMoreRecords();
  }

  handleSearch(event) {
    const value = event.target.value;
    this.searchKey = value;

    clearTimeout(this.debounceTimeout);
    this.debounceTimeout = setTimeout(() => {
      this.searchKey = value;

      if (this.searchKey.length >= 3 || this.searchKey.length === 0) {
        this.updateUrl();
        this.resetAndReload();
      }
    }, 300);
  }

  handleApplicationChange(event) {
    this.selectedApplication = event.detail.value;
    this.updateUrl();
    this.resetAndReload();
  }

  handleEnvironmentChange(event) {
    this.selectedEnvironment = event.detail.value;
    this.updateUrl();
    this.resetAndReload();
  }

  handleClick(event) {
    const recordId = event.currentTarget.dataset.id;
    if (!recordId) {
      return;
    }

    const baseUrl = window.location.origin;
    
    const targetUrl = `${baseUrl}/s/data-publication-details?id=${recordId}&env=${this.selectedEnvironment?.trim() || 'Dev'}`;

    window.open(targetUrl, "_self");
  }

  get activeFiltersCount() {
    let count = 0;
    if (this.searchKey) count++;
    if (this.selectedApplication) count++;
    if (this.selectedEnvironment) count++;
    return count;
  }

  async loadMoreRecords() {
    if (!this.hasMoreData || this.isLoading) return;

    this.isLoading = true;
    this.hasError = false;

    try {
      const result = await fetchAssets({
        searchKey: this.searchKey,
        application: this.selectedApplication,
        environment:this.selectedEnvironment,
        offsetSize: this.offset,
        limitSize: this.pageSize
      });

      if (result.length < this.pageSize) {
        this.hasMoreData = false;
      }

      this.offset += result.length;
      this.displayedRecords = [...this.displayedRecords, ...result];
    } catch (e) {
      this.hasError = true;
      this.logExceptionToApex(e, "loadMoreRecords");
    } finally {
      this.isLoading = false;
    }
  }

  handleScroll() {
    if (!window || this.isPreview || this.isLoading || !this.hasMoreData) {
      return;
    }

    const scrollPosition = window.innerHeight + window.scrollY;
    const threshold = document.body.offsetHeight - this.scrollThreshold;

    if (scrollPosition >= threshold) {
      this.loadMoreRecords();
    }
  }

  scrollToTop() {
    window.scrollTo({ top: 0, behavior: "smooth" });
  }

  get showSkeletons() {
    return this.isLoading && this.displayedRecords.length === 0;
  }
  get showNoBackendData() {

    return (
      !this.isLoading &&
      !this.hasError &&
      this.displayedRecords.length === 0 &&
      !this.hasActiveFilters
    );

  }

  get showNoFilteredData() {
    return (
      !this.isLoading &&
      this.displayedRecords &&
      this.displayedRecords.length === 0 &&
      ((this.searchKey && this.searchKey.length >= 3) ||
        this.selectedApplication || this.selectedEnvironment)
    );
  }

  get showGrid() {
    return !this.hasError && this.filteredRecords.length > 0;
  }

  get filteredRecords() {
    return this.displayedRecords.map((rec, i) => {
      const colIndex = i % 3;
      return {
        ...rec,
        cardStyle: `--card-color:${this.columnColors[colIndex]}`
      };
    });
  }
  logExceptionToApex(error, operation = "unknown", recordId = null) {
    try {
      // Prepare transaction context if needed
      const transactionContext = {
        searchKey: this.searchKey,
        selectedApplication: this.selectedApplication,
        displayedRecords: this.displayedRecords.length
      };

      logError({
        message: error?.message || "Unknown error",
        componentType: "LWC",
        componentName: "AEHC_DataPublicationCatalog",
        operation: operation,
        recordId: recordId,
        severity: "High",
        category: "UI",
        transactionContext: transactionContext,
        orgEnv: LABEL_ENV_NAME
      }).catch((err) => console.error("Failed to log error in Apex", err));
    } catch (ex) {
      console.error("Local logging failed", ex);
    }
  }

  get hasActiveFilters() {
    return this.activeFiltersCount > 0;
  }

  get disableClearAll() {
    return !this.hasActiveFilters;
  }

  handleClearAll() {
    this.searchKey = "";
    this.selectedApplication = "";
    this.selectedEnvironment = "";
    this.updateUrl();
    this.resetAndReload();
  }

  toggleFilters() {
    this.filtersOpen = !this.filtersOpen;
  }

  get filterContainerClass() {
    return `filter-row-collapsible ${this.filtersOpen ? "open" : ""}`;
  }
}